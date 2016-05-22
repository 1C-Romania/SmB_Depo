#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Auxiliary functions

Function GetEmptyResultStructure() Export
	
	Structure = New Structure;
	Structure.Insert("ProductsTable", 							 Undefined);
	Structure.Insert("AccordanceFieldsDCSColumnsOfTablesProducts", New Map);
	
	Return Structure;
	
EndFunction // GetEmptyResultStructure()

Function GetEmptySettingsStructure() Export
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("MandatoryFields"   , 			  New Array);
	SettingsStructure.Insert("DataParameters"    , 			  New Structure);
	SettingsStructure.Insert("SettingsComposer"  , 			  Undefined); // Filter
	SettingsStructure.Insert("DataCompositionSchemaTemplateName" , Undefined);
	
	Return SettingsStructure;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// WORK WITH DCS

// Among the DCS field items find filed by name.
//
Function FindDCSFieldByName(Items, Name)
	
	For Each Item IN Items Do
		If UPPER(String(Item.Field)) = UPPER(Name) Then
			Return Item;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction // FindDCSFieldByName()

// Find DCS field by full name.
//
Function FindDCSFieldByDescriptionFull(Items, FullName) Export

	arrOfNamesParts = FromFullFieldNameGetParts(FullName);
	numOfParts 	  = arrOfNamesParts.Count();
	
	curName = arrOfNamesParts[0];
	Field   = FindDCSFieldByName(Items, curName);
	
	If Field = Undefined Then
		Return Undefined;
	EndIf;
	
	For Ct = 2 To numOfParts Do
		
		curName = curName + "." + arrOfNamesParts[Ct-1];
		Field   = FindDCSFieldByName(Field.Items, curName);
		
		If Field = Undefined Then
			Return Undefined;
		EndIf;
		
	EndDo;
	
	Return Field;

EndFunction // FindDCSFieldByFullName()

// Divide full field name into parts
//
Function FromFullFieldNameGetParts(FullName)

	arrOfParts = New Array;
	StrName 	  = FullName;
	
	While Not IsBlankString(StrName) Do
		
		If Left(StrName, 1) = "[" Then
			
			Pos = Find(StrName, "]");
			If Pos = 0 Then
				arrOfParts.Add(Mid(StrName, 2));
				StrName = "";
			Else
				arrOfParts.Add(Mid(StrName, 1, Pos));
				StrName = Mid(StrName, Pos + 2);
			EndIf;
			
		Else
			
			Pos = Find(StrName, ".");
			If Pos = 0 Then
				arrOfParts.Add(StrName);
				StrName = "";
			Else
				arrOfParts.Add(Left(StrName, Pos - 1));
				StrName = Mid(StrName, Pos + 1);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return arrOfParts;

EndFunction // FromFullFieldNameGetParts()


Procedure SetFilterByPricesType(Composer)
	
	FilterPricesType = FindFilterItemByName(Composer.Settings.Filter, "PricesType");
	
	If FilterPricesType = Undefined Then
		Return; // there is no such filter in DCS
	EndIf;
	
	If Not FilterPricesType.Use
		OR FilterPricesType.ComparisonType <> DataCompositionComparisonType.Equal Then
		
		If FilterPricesType.Use Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Filter is possible only by one price type. Information on the item prices is not filled.'"));
		EndIf;
		
		FilterPricesType.Use  = True;
		FilterPricesType.ComparisonType   = DataCompositionComparisonType.Equal;
		FilterPricesType.RightValue = Catalogs.PriceKinds.EmptyRef();
		
	EndIf;
	
EndProcedure

Function FindFilterItemByName(Filter, ItemName)
	
	CompositionField = New DataCompositionField(ItemName);
	Result 	   = Undefined;
	
	For Each CurItem IN Filter.Items Do
		
		If TypeOf(CurItem) = Type("DataCompositionFilterItemGroup") Then
			Result = FindFilterItemByName(CurItem, ItemName);
			If Not Result = Undefined Then
				Break;
			EndIf;
		Else
			If CurItem.LeftValue = CompositionField Then
				Result = CurItem;
				Break;
			EndIf;
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// TABLE FORMATION

// Function prepares the data structure required to print labels and price tags.
//
// Returns:
//  Structure - data that is necessary for printing the labels and price tags.
//
Function PrepareDataStructure(SettingsStructure) Export
	
	ResultStructure = GetEmptyResultStructure();
	
	////////////////////////////////////////////////////////////////////////////////
	// DATA COMPOSITION SCHEMA PREPARATION AND DCS SETTINGS COMPOSER
	
	// Composition schema.
	DataCompositionSchema = DataProcessors.ElectronicDocumentsSendDirectory.GetTemplate(SettingsStructure.DataCompositionSchemaTemplateName);
	
	// Preparation layout composer of data configuration.
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	Composer.LoadSettings(DataCompositionSchema.DefaultSettings);
	Composer.Settings.Filter.Items.Clear();
	
	// Setting composer filter.
	If SettingsStructure.SettingsComposer <> Undefined Then
		DataProcessors.PrintLabelsAndTags.CopyItems(Composer.Settings.Filter, SettingsStructure.SettingsComposer.Settings.Filter);
	EndIf;
	
	SetFilterByPricesType(Composer);
	
	// Selected fields of setting composer.
	For Each MandatoryField IN SettingsStructure.MandatoryFields Do
		DCSField = FindDCSFieldByDescriptionFull(Composer.Settings.Selection.SelectionAvailableFields.Items, MandatoryField);
		If DCSField <> Undefined Then
			SelectedField = Composer.Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
			SelectedField.Field = DCSField.Field;
		EndIf;
	EndDo;
	
	// Layout configuration of data configuration.
	TemplateComposer 	  = New DataCompositionTemplateComposer;
	DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Composer.Settings,,,Type("DataCompositionValueCollectionTemplateGenerator"));
	
	////////////////////////////////////////////////////////////////////////////////
	// AUXILIARY DATA REPARATION FOR TEMPLATE FIELD MAPPING AND DCS
	
	For Each Field IN DataCompositionTemplate.DataSets.DataSet.Fields Do
		ResultStructure.AccordanceFieldsDCSColumnsOfTablesProducts.Insert(
			Catalogs.LabelsAndTagsTemplates.GetFieldNameInTemplate(Field.DataPath),
			Field.Name);
	EndDo;
	
	////////////////////////////////////////////////////////////////////////////////
	// Query execution
	
	Query = New Query(DataCompositionTemplate.DataSets.DataSet.Query);
	
	// Filling the parameters from filter composer fields of the form settings data processor.
	For Each Parameter IN DataCompositionTemplate.ParameterValues Do
		Query.Parameters.Insert(Parameter.Name, Parameter.Value);
	EndDo;
	
	ResultStructure.ProductsTable = Query.Execute().Unload();
	
	Return ResultStructure;
	
EndFunction // PrepareDataStructure()

#EndIf