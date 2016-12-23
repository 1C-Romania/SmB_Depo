////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	For Each String IN Metadata.DocumentJournals.WarehouseWarrants.RegisteredDocuments Do
		Items.DocumentType.ChoiceList.Add(String.Synonym, String.Synonym);
		DocumentTypes.Add(String.Synonym, String.Name);
	EndDo;
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure

// Procedure - form event handler BeforeImportDataFromSettingsAtServer.
//
&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	Company						= Settings.Get("Company");
	DocumentTypePresentation		= Settings.Get("DocumentTypePresentation");
	Warehouse							= Settings.Get("Warehouse");
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	SmallBusinessClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	SmallBusinessClientServer.SetListFilterItem(List, "Warehouse", Warehouse, ValueIsFilled(Warehouse));
	
EndProcedure // BeforeImportDataFromSettingsAtServer()

&AtClient
// Procedure - opening handler Warehouse.
//
Procedure WarehouseOpening(Item, StandardProcessing)
	
	If Items.Warehouse.ListChoiceMode
		AND Not ValueIsFilled(Warehouse) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // WarehouseOpening()

&AtClient
// Procedure - event handler OnChange of attribute DocumentType.
//
Procedure DocumentTypeOnChange(Item)
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	SmallBusinessClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute StoragePlace.
//
Procedure StoragePlaceOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Warehouse", Warehouse, ValueIsFilled(Warehouse));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company attribute.
//
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
// Procedure - list event handler BeforeAddStart.
//
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ValueIsFilled(DocumentType) Then
		
		Cancel = True;
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("StructuralUnit", Warehouse);
		ParametersStructure.Insert("Company", Company);
		
		OpenForm("Document." + DocumentType + ".ObjectForm", New Structure("FillingValues", ParametersStructure));
		
	EndIf;
	
EndProcedure // ListBeforeAddRow()














