#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SetDataDesign();
	
	If Parameters.ImportType = "TabularSection" AND ValueIsFilled(Parameters.TabularSectionFullName) Then 
		AmbiguitiesList = New Array;
		
		ObjectArray = StringFunctionsClientServer.SplitStringIntoWordArray(Parameters.TabularSectionFullName);
		If ObjectArray[0] = "Document" Then
			ObjectManager = Documents[ObjectArray[1]];
		ElsIf ObjectArray[0] = "Catalog" Then
			ObjectManager = Catalogs[ObjectArray[1]];
		Else
			Cancel = True;
			Return;
		EndIf;
		
		Try
			ObjectManager.FillAmbiguitiesList(Parameters.TabularSectionFullName, AmbiguitiesList, Parameters.Name, Parameters.ImportedColumnValues, Parameters.AdditionalParameters);
		Except
			// An old variant of the FillAmbiguitiesList method without the AdditionalParameters parameter.
			ObjectManager.FillAmbiguitiesList(Parameters.TabularSectionFullName, AmbiguitiesList, Parameters.Name, Parameters.ImportedColumnValues);
		EndTry;
		
		Items.VariantDisambiguation.Visible = False;
		Items.DecorationHeader.Title = StringFunctionsClientServer.PlaceParametersIntoString(Items.DecorationHeader.Title, Parameters.Name);
		Items.DecorationHeader.Visible = True;
		Items.DecorationLoadFromFile.Visible = False;
		Items.CatalogItems.CommandBar.ChildItems.CatalogItemsNewItem.Visible = False;
		For Each Column IN Parameters.ImportedColumnValues Do 
			CorrelationColumns.Add(Column.Key);
		EndDo;
		Items.DecorationHeaderRefSearch.Visible = False;
		
	ElsIf Parameters.ImportType = "InsertionFromClipboard" Then
		Items.GroupDataFromFile.Visible = False;
		Items.DecorationHeader.Visible = False;
		Items.DecorationLoadFromFile.Visible = False;
		Items.DecorationHeaderRefSearch.Visible = True;
		AmbiguitiesList = Parameters.AmbiguitiesList;
		CorrelationColumns = Parameters.CorrelationColumns;
	Else 
		AmbiguitiesList = Parameters.AmbiguitiesList;
		CorrelationColumns = Parameters.CorrelationColumns;
		Items.DecorationHeader.Visible = False;
		Items.DecorationLoadFromFile.Visible = True;
		Items.DecorationHeaderRefSearch.Visible = False;
	EndIf;
	IndexOf = 0;
	
	If AmbiguitiesList.Count() = 0 Then
		Cancel = True;
		Return;
	EndIf;
	
	TemporaryVT = FormAttributeToValue("CatalogItems");
	TemporaryVT.Columns.Clear();
	AttributeArray = New Array;

	FirstItem = AmbiguitiesList.Get(0);
	MetadataObject = FirstItem.Metadata();
	
	For Each Attribute IN FirstItem.Metadata().Attributes Do
		If Attribute.Type.Types().Find(Type("ValueStorage")) = Undefined Then
			TemporaryVT.Columns.Add(Attribute.Name, Attribute.Type, Attribute.Presentation());
			AttributeArray.Add(New FormAttribute(Attribute.Name, Attribute.Type, "CatalogItems", Attribute.Presentation()));
		EndIf;
	EndDo;
	
	For Each Attribute IN MetadataObject.StandardAttributes Do
		TemporaryVT.Columns.Add(Attribute.Name, Attribute.Type, Attribute.Presentation());
		AttributeArray.Add(New FormAttribute(Attribute.Name, Attribute.Type, "CatalogItems", Attribute.Presentation()));
	EndDo;
	
	For Each Item IN Parameters.StringFromTable Do
		AttributeArray.Add(New FormAttribute("Individual_" + Item[IndexOf], New TypeDescription("String"),, Item[1]));
	EndDo;
	
	ChangeAttributes(AttributeArray);
	
	Items.CatalogItems.Height = AmbiguitiesList.Count() + 3;
	
	For Each Item IN AmbiguitiesList Do
		String = SelectionVariants.GetItems().Add();
		String.Presentation = String(Item);
		String.Ref = Item.Ref;
		MetadataObject = Item.Metadata();
		
		For Each Attribute IN MetadataObject.StandardAttributes Do
			If Attribute.Name = "Code" OR Attribute.Name = "Description" Then
				Substring = String.GetItems().Add();
				Substring.Presentation = Attribute.Presentation() + ":";
				Substring.Value = Item[Attribute.Name];
				Substring.Ref = Item.Ref;
			EndIf;
		EndDo;
		
		For Each Attribute IN MetadataObject.Attributes Do
			Substring = String.GetItems().Add();
			Substring.Presentation = Attribute.Presentation() + ":";
			Substring.Value = Item[Attribute.Name];
			Substring.Ref = Item.Ref;
		EndDo;
	
	EndDo;
	
	For Each Item IN AmbiguitiesList Do
		String = CatalogItems.Add();
		String.Presentation = String(Item);
		For Each Column IN TemporaryVT.Columns Do
			Try
				String[Column.Name] = Item[Column.Name];
			Except
				// A fall is possible during an incorrect type cast
			EndTry;
		EndDo;
	EndDo;
	
	For Each Column IN TemporaryVT.Columns Do
		NewItem = Items.Add(Column.Name, Type("FormField"), Items.CatalogItems);
		NewItem.Type = FormFieldType.InputField;
		NewItem.DataPath = "CatalogItems." + Column.Name;
		NewItem.Title = Column.Title;
	EndDo;
	
	If Parameters.ImportType = "InsertionFromClipboard" Then
		Delimiter = "";
		RowWithValues = "";
		For Each Item IN Parameters.StringFromTable Do
			RowWithValues = RowWithValues + Delimiter + Item[2];
			Delimiter = ", ";
		EndDo;
		If StrLen(RowWithValues) > 70 Then
			RowWithValues = Left(RowWithValues, 70) + "...";
		EndIf;
		Items.DecorationHeaderRefSearch.Title = StringFunctionsClientServer.PlaceParametersIntoString(Items.DecorationHeaderRefSearch.Title,
				 RowWithValues);
	Else
		CollapsedItemsQuantity = 0;
		For Each Item IN Parameters.StringFromTable Do
			
			If Parameters.StringFromTable.Count() > 3 Then 
				If CorrelationColumns.FindByValue(Item[IndexOf]) = Undefined Then
					GroupOfItems = Items.OtherDataFromFile;
					CollapsedItemsQuantity = CollapsedItemsQuantity + 1;
				Else
					GroupOfItems = Items.MainDataFromFile;
				EndIf;
			Else
				GroupOfItems = Items.MainDataFromFile;
			EndIf;
			
			NewItem2 = Items.Add(Item[IndexOf] + "_val", Type("FormField"), GroupOfItems);
			NewItem2.DataPath = "Individual_"+Item[IndexOf];
			NewItem2.Title = Item[1];
			NewItem2.Type = FormFieldType.InputField;
			NewItem2.ReadOnly = True;
			ThisObject["Individual_" + Item[IndexOf]] = Item[2];
		EndDo;
	EndIf;
	
	Items.OtherDataFromFile.Title = Items.OtherDataFromFile.Title + " (" +String(CollapsedItemsQuantity) + ")";
	ThisObject.Height = Parameters.StringFromTable.Count() + AmbiguitiesList.Count() + 7;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	Close(Items.SelectionVariants.CurrentData.Ref);
EndProcedure

&AtClient
Procedure NewItem(Command)
	Close(Undefined);
EndProcedure

#EndRegion

#Region TableItemEventsHandlersCatalogItems

&AtClient
Procedure CatalogItemsSelection(Item, SelectedRow, Field, StandardProcessing)
	Close(Items.CatalogItems.CurrentData.Ref);
EndProcedure

&AtClient
Procedure DisambiguationVariantOnChange(Item)
	Items.CatalogItems.ReadOnly = Not VariantDisambiguation;
EndProcedure

&AtClient
Procedure SelectionVariantsSelection(Item, SelectedRow, Field, StandardProcessing)
	If ValueIsFilled(Item.CurrentData.Ref) AND Field.Name="SelectionVariantsValue" Then
		StandardProcessing = False;
		ShowValue(, Item.CurrentData.Ref);
	ElsIf ValueIsFilled(Item.CurrentData.Ref) AND Field.Name="SelectionVariantsPresentation" Then
		StandardProcessing = False;
		Close(Items.SelectionVariants.CurrentData.Ref);
	EndIf;
EndProcedure

#EndRegion

#Region ServiceFunctions

&AtServer
Procedure SetDataDesign()
	
	ConditionalAppearance.Items.Clear();
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("SelectionVariantsValue");
	AppearanceField.Use = True;
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("SelectionVariants.Value"); 
	FilterItem.ComparisonType = DataCompositionComparisonType.NotFilled; 
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

#EndRegion
