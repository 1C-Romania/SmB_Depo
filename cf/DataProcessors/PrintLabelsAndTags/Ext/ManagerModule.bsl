#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Auxiliary functions

Procedure FillItems(ReceiverValues, ValueSource, FirstLevel = Undefined) Export
	
	If TypeOf(ReceiverValues) = Type("DataCompositionParameterValueCollection") Then
		CollectionValues = ValueSource;
	Else
		CollectionValues = ValueSource.Items;
	EndIf;
	
	For Each ItemSource IN CollectionValues Do
		If FirstLevel = Undefined Then
			ItemReceiver = ReceiverValues.FindParameterValue(ItemSource.Parameter);
		Else
			ItemReceiver = FirstLevel.FindParameterValue(ItemSource.Parameter);
		EndIf;
		If ItemReceiver = Undefined Then
			Continue;
		EndIf;
		FillPropertyValues(ItemReceiver, ItemSource);
		If TypeOf(ItemSource) = Type("DataCompositionParameterValue") Then
			If ItemSource.NestedParameterValues.Count() <> 0 Then
				FillItems(ItemReceiver.NestedParameterValues, ItemSource.NestedParameterValues, ReceiverValues);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Copies items from one collection to another
Procedure CopyItems(ReceiverValues, ValueSource, CheckEnabled = False, ClearReceiver = True) Export
	
	If TypeOf(ValueSource) = Type("DataCompositionConditionalAppearance")
		OR TypeOf(ValueSource) = Type("DataCompositionUserFieldsCaseVariants")
		OR TypeOf(ValueSource) = Type("DataCompositionAppearanceFields")
		OR TypeOf(ValueSource) = Type("DataCompositionDataParameterValues") Then
		CreateByType = False;
	Else
		CreateByType = True;
	EndIf;
	ReceiverElements = ReceiverValues.Items;
	SourceElements = ValueSource.Items;
	If ClearReceiver Then
		ReceiverElements.Clear();
	EndIf;
	
	For Each ItemSource IN SourceElements Do
		
		If TypeOf(ItemSource) = Type("DataCompositionOrderItem") Then
			// Add order items to the beginning
			IndexOf = SourceElements.IndexOf(ItemSource);
			ItemReceiver = ReceiverElements.Insert(IndexOf, TypeOf(ItemSource));
		Else
			If CreateByType Then
				ItemReceiver = ReceiverElements.Add(TypeOf(ItemSource));
			Else
				ItemReceiver = ReceiverElements.Add();
			EndIf;
		EndIf;
		
		FillPropertyValues(ItemReceiver, ItemSource);
		// IN some collections it is required to fill other collections
		If TypeOf(SourceElements) = Type("DataCompositionConditionalAppearanceItemCollection") Then
			CopyItems(ItemReceiver.Fields, ItemSource.Fields);
			CopyItems(ItemReceiver.Filter, ItemSource.Filter);
			FillItems(ItemReceiver.Appearance, ItemSource.Appearance); 
		ElsIf TypeOf(SourceElements)	= Type("DataCompositionUserFieldCaseVariantCollection") Then
			CopyItems(ItemReceiver.Filter, ItemSource.Filter);
		EndIf;
		
		// IN some collection items it is required to fill other collections
		If TypeOf(ItemSource) = Type("DataCompositionFilterItemGroup") Then
			CopyItems(ItemReceiver, ItemSource);
		ElsIf TypeOf(ItemSource) = Type("DataCompositionSelectedFieldGroup") Then
			CopyItems(ItemReceiver, ItemSource);
		ElsIf TypeOf(ItemSource) = Type("DataCompositionUserFieldCase") Then
			CopyItems(ItemReceiver.Variants, ItemSource.Variants);
		ElsIf TypeOf(ItemSource) = Type("DataCompositionUserFieldExpression") Then
			ItemReceiver.SetDetailRecordExpression (ItemSource.GetDetailRecordExpression());
			ItemReceiver.SetTotalRecordExpression(ItemSource.GetTotalRecordExpression());
			ItemReceiver.SetDetailRecordExpressionPresentation(ItemSource.GetDetailRecordExpressionPresentation ());
			ItemReceiver.SetTotalRecordExpressionPresentation(ItemSource.GetTotalRecordExpressionPresentation ());
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetEmptyResultStructure() Export
	
	Structure = New Structure;
	Structure.Insert("ProductsTable" , Undefined);
	Structure.Insert("AccordanceFieldsDCSColumnsOfTablesProducts", New Map);
	
	Return Structure;
	
EndFunction // GetEmptyResultStructure()

Function GetEmptySettingsStructure() Export
	
	//SourceData = New ValueTable;
	//SourceData.Columns.Add("ProductsAndServices",   New TypeDescription("CatalogRef.ProductsAndServices"));
	//SourceData.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsAndServicesCharacteristics"));
	//SourceData.Columns.Add("Batch",       New TypeDescription("CatalogRef.ProductsAndServicesPacking"));
	//SourceData.Columns.Add("Quantity",     New TypeDescription("Number"));
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("SourceData"     , Undefined); // Table with arbitrary data
	SettingsStructure.Insert("MandatoryFields"   , New Array); //
	SettingsStructure.Insert("AccordanceOfTemplatesAndTemplateStructure" , New Map); //
	SettingsStructure.Insert("DataParameters"    , New Structure);
	SettingsStructure.Insert("SettingsComposer", Undefined); // Filter
	SettingsStructure.Insert("DataCompositionSchemaTemplateName" , Undefined);
	
	Return SettingsStructure;
	
EndFunction

Function GetParameterNameBarcode()
	
	Return "Barcode";
	
EndFunction // GetParameterNameBarcode()

// Function determines whether the form attribute exists.
//
Function IsObjectAttribute(Object, AttributeName)
	
	UniqueKey   = New UUID;

	AttributeStructure = New Structure(AttributeName, UniqueKey);

	FillPropertyValues(AttributeStructure, Object);
	
	Return AttributeStructure[AttributeName] <> UniqueKey;
	
EndFunction // ThereIsObjectAttribute()

Function SetDCSParameterValue(SettingsComposer, ParameterName, ParameterValue, UseNotFilled = True)
	
	ParameterInstalled = False;
	
	ParameterPriceKind = New DataCompositionParameter(ParameterName);
	ParameterValuePriceKind = SettingsComposer.Settings.DataParameters.FindParameterValue(ParameterPriceKind);
	If ParameterValuePriceKind <> Undefined Then
		
		ParameterValuePriceKind.Value = ParameterValue;
		ParameterValuePriceKind.Use = ?(UseNotFilled, True, ValueIsFilled(ParameterValuePriceKind.Value));
		
		ParameterInstalled = True;
		
	EndIf;
	
	Return ParameterInstalled;
	
EndFunction // SetDCSParameterValue()

// <Function description>
//
// Parameters
//  <Parameter1>  - <Type.Kind> - <parameter description>
//                  <parameter description continuation>
//  <Parameter2>  - <Type.Kind> - <parameter description>
//                  <parameter description continuation>
//
// Returns:
//   <Type.Kind>   - <return value description>
//
Function GroupValueTableByAttribute(TableAttributesDocuments, AttributeName) Export
	
	Table = TableAttributesDocuments.Copy();
	Table.GroupBy(AttributeName);
	Return Table;
	
EndFunction // GroupValueTableByAttribute()

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
	numOfParts = arrOfNamesParts.Count();
	
	curName = arrOfNamesParts[0];
	Field = FindDCSFieldByName(Items, curName);
	If Field = Undefined Then
		Return Undefined;
	EndIf;
	
	For Ct = 2 To numOfParts Do
		curName = curName +"." + arrOfNamesParts[Ct-1];
		Field = FindDCSFieldByName(Field.Items, curName);
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
	StrName = FullName;
	
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

////////////////////////////////////////////////////////////////////////////////
// PRINT PROCEDURES

// Function forms table document with price tags and labels.
//
// Returns:
//  Spreadsheet document - printing form with price tags and labels.
//
Function GeneratePriceTagsAndLabelsPrintForms(SettingsStructure) Export
	
	////////////////////////////////////////////////////////////////////////////////
	// TEMPLATE DATA STRUCTURE PREPARATION
	
	ResultStructure = PrepareDataStructure(SettingsStructure);
	
	////////////////////////////////////////////////////////////////////////////////
	// TABLE DOCUMENT FORMATION
	
	Prototype = DataProcessors.PrintLabelsAndTags.GetTemplate("Prototype");
	CountNumberOfMillimetersInPixel = Prototype.Drawings.Square100Pixels.Height / 100;
	
	// Print form collection preparation.
	PrintFormsCollection = New ValueTable;
	PrintFormsCollection.Columns.Add("TemplateName");
	PrintFormsCollection.Columns.Add("SpreadsheetDocument");
	PrintFormsCollection.Columns.Add("ColumnNameCount");
	PrintFormsCollection.Columns.Add("ColumnNameTemplate");
	PrintFormsCollection.Columns.Add("Pattern");
	
	For Each KeyAndValue IN SettingsStructure.AccordanceOfTemplatesAndTemplateStructure Do
		
		If SettingsStructure.NeedToPrintLabels Then
			PrintForm = PrintFormsCollection.Add();
			PrintForm.TemplateName            = "Label: "+KeyAndValue.Key;
			PrintForm.ColumnNameCount = "LabelsQuantityToPrint";
			PrintForm.ColumnNameTemplate     = "LabelTemplateToPrint";
			PrintForm.Pattern = KeyAndValue.Key;
		EndIf;
		
		If SettingsStructure.NeedToPrintTags Then
			PrintForm = PrintFormsCollection.Add();
			PrintForm.TemplateName            = "PriceTag: " + KeyAndValue.Key;
			PrintForm.ColumnNameCount = "PricetagsForPrintCount";
			PrintForm.ColumnNameTemplate     = "PriceTagsTemplateToPrint";
			PrintForm.Pattern = KeyAndValue.Key;
		EndIf;
		
	EndDo;
	
	For Each PrintForm IN PrintFormsCollection Do
		
		ColumnNumber = 0;
		NumberSeries = 0;
		
		For Each StringInventory IN ResultStructure.ProductsTable Do
			
			If StringInventory[PrintForm.ColumnNameCount] > 0 AND StringInventory[PrintForm.ColumnNameTemplate] = PrintForm.Pattern Then
				
				StructureTemplate = SettingsStructure.AccordanceOfTemplatesAndTemplateStructure.Get(StringInventory[PrintForm.ColumnNameTemplate]);
				
				If PrintForm.SpreadsheetDocument = Undefined Then
					PrintForm.SpreadsheetDocument = New SpreadsheetDocument;
				EndIf;
				
				Area = StructureTemplate.TemplateLabel.GetArea(StructureTemplate.PrintAreaName);
				
				// Setting application of table document.
				FillPropertyValues(PrintForm.SpreadsheetDocument, StructureTemplate.TemplateLabel, , "PrintArea");
				
				For Each ParameterTemplate IN StructureTemplate.TemplateParameters Do
					If IsObjectAttribute(Area.Parameters, ParameterTemplate.Value) Then
						ColumnDescription = ResultStructure.AccordanceFieldsDCSColumnsOfTablesProducts.Get(Catalogs.LabelsAndTagsTemplates.GetFieldNameInTemplate(ParameterTemplate.Key));
						If ColumnDescription <> Undefined Then
							
							If TypeOf(StringInventory[ColumnDescription]) = Type("Date") Then
								
								Area.Parameters[ParameterTemplate.Value] = Format(StringInventory[ColumnDescription], "DLF=D");
								
							Else
								
								Area.Parameters[ParameterTemplate.Value] = StringInventory[ColumnDescription];
								
							EndIf;
							
						EndIf;
					EndIf;
				EndDo;
				
				For Each Draw IN Area.Drawings Do
					If Left(Draw.Name,8) = GetParameterNameBarcode() Then
						
						BarcodeValue = StringInventory[ResultStructure.AccordanceFieldsDCSColumnsOfTablesProducts.Get(GetParameterNameBarcode())];
						If ValueIsFilled(BarcodeValue) Then
							BarcodeParameters = New Structure;
							BarcodeParameters.Insert("Width", Draw.Width / CountNumberOfMillimetersInPixel);
							BarcodeParameters.Insert("Height", Draw.Height / CountNumberOfMillimetersInPixel);
							BarcodeParameters.Insert("Barcode", BarcodeValue);
							BarcodeParameters.Insert("CodeType", StructureTemplate.CodeType);
							BarcodeParameters.Insert("ShowText", True);
							BarcodeParameters.Insert("SizeOfFont", 12);
							Draw.Picture = EquipmentManagerServerCall.GetBarcodePicture(BarcodeParameters);
						EndIf;
						
					EndIf;
				EndDo;
				
				For Ind = 1 To StringInventory[PrintForm.ColumnNameCount] Do // Cycle by quantity of copies
					
					ColumnNumber = ColumnNumber + 1;
					
					If ColumnNumber = 1 Then
						
						NumberSeries = NumberSeries + 1;
						
						PrintForm.SpreadsheetDocument.Put(Area);
						
					Else
						
						PrintForm.SpreadsheetDocument.Join(Area);
						
					EndIf;
					
					If ColumnNumber = StructureTemplate.CountByHorizontal AND NumberSeries = StructureTemplate.VerticalQuantity Then
						
						NumberSeries    = 0;
						ColumnNumber = 0;
						
						PrintForm.SpreadsheetDocument.PutHorizontalPageBreak();
						
					ElsIf ColumnNumber = StructureTemplate.CountByHorizontal Then
						
						ColumnNumber = 0;
						
					EndIf;
					
				EndDo; // Cycle by quantity of copies
			
			EndIf;
			
		EndDo; // Cycle by the product table rows
		
	EndDo;
	
	RowToDeleteArray = New Array;
	For Each PrintForm IN PrintFormsCollection Do
		If PrintForm.SpreadsheetDocument = Undefined Then
			RowToDeleteArray.Add(PrintForm);
		EndIf;
	EndDo;
	For Each PrintForm IN RowToDeleteArray Do
		PrintFormsCollection.Delete(PrintForm);
	EndDo;
	
	Return PrintFormsCollection;
	
EndFunction // GeneratePriceTagsAndLabelsPrintForms()

// Document printing procedure.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	SourceData = PrintParameters.PrintInfo[0].Inventory.Unload(New Structure("Selected", True), "ProductsAndServices, Characteristic, Batch, Barcode, PriceTagsQuantity, PriceTagsTemplate, LabelsQuantity, LabelTemplate");
	NeedToPrintTags = PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Price Tags");
	NeedToPrintLabels = PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Labels");
	
	SettingsStructure = GetEmptySettingsStructure();
	SettingsStructure.MandatoryFields.Add("PricetagsForPrintCount");
	SettingsStructure.MandatoryFields.Add("LabelsQuantityToPrint");
	SettingsStructure.MandatoryFields.Add("PriceTagsTemplateToPrint");
	SettingsStructure.MandatoryFields.Add("LabelTemplateToPrint");
	SettingsStructure.MandatoryFields.Add("ProductsAndServices");
	If GetFunctionalOption("UseCharacteristics") Then
		SettingsStructure.MandatoryFields.Add("Characteristic");
	EndIf;
	If GetFunctionalOption("UseBatches") Then
		SettingsStructure.MandatoryFields.Add("Batch");
	EndIf;
	
	SettingsStructure.DataCompositionSchemaTemplateName = "TemplateFields";
	
	// Collect used fields from templates.
	If NeedToPrintTags Then
		TableOfTemplates = PrintParameters.PrintInfo[0].Inventory.Unload(New Structure("Selected", True), "PriceTagsTemplate, PriceTagsQuantity");
	Else
		TableOfTemplates = PrintParameters.PrintInfo[0].Inventory.Unload(New Structure("Selected", True), "LabelTemplate, LabelsQuantity");
	EndIf;
	
	MapTemplates = New Map;
	For Each TSRow IN TableOfTemplates Do
		If NeedToPrintLabels AND ValueIsFilled(TSRow.LabelTemplate) AND TSRow.LabelsQuantity > 0 Then
			MapTemplates.Insert(TSRow.LabelTemplate);
		EndIf;
		If NeedToPrintTags AND ValueIsFilled(TSRow.PriceTagsTemplate) AND TSRow.PriceTagsQuantity > 0 Then
			MapTemplates.Insert(TSRow.PriceTagsTemplate);
		EndIf;
	EndDo;
	
	// Fill mandatory fields collection and form template compliance.
	For Each KeyAndValue IN MapTemplates Do
		
		StructureTemplate = KeyAndValue.Key.Pattern.Get();
		
		// Template structure.
		SettingsStructure.AccordanceOfTemplatesAndTemplateStructure.Insert(KeyAndValue.Key, StructureTemplate);
		
		// Add fields of the price tag print form into the mandatory fields array.
		For Each Item IN StructureTemplate.TemplateParameters Do
			SettingsStructure.MandatoryFields.Add(Item.Key);
		EndDo;
		
	EndDo;
	
	// Preparation of source data.
	For Each TSRow IN SourceData Do
		If NeedToPrintLabels AND Not ValueIsFilled(TSRow.LabelTemplate) Then
			TSRow.LabelsQuantity = 0;
		EndIf;
		If NeedToPrintTags AND Not ValueIsFilled(TSRow.PriceTagsTemplate) Then
			TSRow.PriceTagsQuantity = 0;
		EndIf;
	EndDo;
	
	SettingsStructure.DataParameters.Insert("PriceKind", PrintParameters.PrintInfo[0].PriceKind);
	SettingsStructure.DataParameters.Insert("StructuralUnit", PrintParameters.PrintInfo[0].StructuralUnit);
	SettingsStructure.DataParameters.Insert("Company", PrintParameters.PrintInfo[0].Company);
	
	SettingsStructure.Insert("NeedToPrintTags", NeedToPrintTags);
	SettingsStructure.Insert("NeedToPrintLabels", NeedToPrintLabels);
	
	SettingsStructure.SourceData = SourceData;
	
	// Display table documents in the collection.
	PrintFormCollectionInner = GeneratePriceTagsAndLabelsPrintForms(SettingsStructure);
	PrintFormsCollection.Clear();
	For Each PrintForm IN PrintFormCollectionInner Do
		
		NewForm = PrintFormsCollection.Add();
		NewForm.TemplateName         = PrintForm.TemplateName;
		NewForm.TemplateSynonym     = PrintForm.TemplateName;
		NewForm.NameUPPER           = Upper(PrintForm.TemplateName);
		NewForm.SpreadsheetDocument = PrintForm.SpreadsheetDocument;
		NewForm.SpreadsheetDocument.PrintParametersKey = "PrintParameters_PrintLabelsAndPriceTags";
		NewForm.Copies       = 1;
		
	EndDo;
	
	AvailableAccounts = EmailOperations.AvailableAccounts(True);
	
	OutputParameters.SendingParameters.Insert("Sender",
		?(AvailableAccounts.Count() > 0, AvailableAccounts[0].Ref, Undefined)
		);
	
	OutputParameters.SendingParameters.Insert("Subject", "PriceTags and Labels. Formed " + CurrentSessionDate());
	
EndProcedure // Print()

////////////////////////////////////////////////////////////////////////////////
// LABEL AND PRICE TAG FORMATION

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
	DataCompositionSchema = DataProcessors.PrintLabelsAndTags.GetTemplate(SettingsStructure.DataCompositionSchemaTemplateName);
	
	// Preparation template composer of data configuration.
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	Composer.LoadSettings(DataCompositionSchema.DefaultSettings);
	Composer.Settings.Filter.Items.Clear();
	
	// Setting composer filter.
	If SettingsStructure.SettingsComposer <> Undefined Then
		CopyItems(Composer.Settings.Filter, SettingsStructure.SettingsComposer.Settings.Filter);
	EndIf;
	
	// Selected fields of setting composer.
	For Each MandatoryField IN SettingsStructure.MandatoryFields Do
		DCSField = FindDCSFieldByDescriptionFull(Composer.Settings.Selection.SelectionAvailableFields.Items, MandatoryField);
		If DCSField <> Undefined Then
			SelectedField = Composer.Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
			SelectedField.Field = DCSField.Field;
		EndIf;
	EndDo;
	
	// Filling parameters.
	For Each DataParameter IN SettingsStructure.DataParameters Do
		If DataParameter.Key = "StructuralUnit" Then // If StructuralUnit isn't filled - don't use parameter
			SetDCSParameterValue(Composer, DataParameter.Key, DataParameter.Value, False);
		Else
			SetDCSParameterValue(Composer, DataParameter.Key, DataParameter.Value);
		EndIf;
	EndDo;
	SetDCSParameterValue(Composer, "CurrentTime",        CurrentDate());
	SetDCSParameterValue(Composer, "CurrentUser", Users.CurrentUser());
	
	// Template configuration of data configuration.
	TemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Composer.Settings,,,Type("DataCompositionValueCollectionTemplateGenerator"));
	
	////////////////////////////////////////////////////////////////////////////////
	// AUXILIARY DATA REPARATION FOR TEMPLATE FIELD MAPPING AND DCS
	
	For Each Field IN DataCompositionTemplate.DataSets.DataSet.Fields Do
		ResultStructure.AccordanceFieldsDCSColumnsOfTablesProducts.Insert(Catalogs.LabelsAndTagsTemplates.GetFieldNameInTemplate(Field.DataPath), Field.Name);
	EndDo;
	
	////////////////////////////////////////////////////////////////////////////////
	// QUERY EXECUTION	
	Query = New Query(DataCompositionTemplate.DataSets.DataSet.Query);
	
	// Filling the parameters from filter composer fields of the form settings data processor.
	For Each Parameter IN DataCompositionTemplate.ParameterValues Do
		Query.Parameters.Insert(Parameter.Name, Parameter.Value);
	EndDo;
	
	// Query substitution when printing labels...
	If SettingsStructure.SourceData <> Undefined Then
		
		Query.Text = StrReplace(Query.Text, "Document.SupplierInvoice.Inventory", "&Table");
		Query.Parameters.Insert("Table", SettingsStructure.SourceData);
		
		Query.Text = StrReplace(Query.Text, """Barcode""", "SourceData.Barcode");
		
		Query.Text = StrReplace(Query.Text, """PriceTagsQuantity""", "SourceData.PriceTagsQuantity");
		Query.Text = StrReplace(Query.Text, """PriceTagsTemplate""", "SourceData.PriceTagsTemplate");
		
		Query.Text = StrReplace(Query.Text, """LabelsQuantity""", "SourceData.LabelsQuantity");
		Query.Text = StrReplace(Query.Text, """LabelTemplate""", "SourceData.LabelTemplate");
		
	EndIf;
	
	ResultStructure.ProductsTable = Query.Execute().Unload();
	
	Return ResultStructure;
	
EndFunction // PrepareDataStructure()

#EndIf