//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

&AtServer
// Procedure - form event handler OnCreateAtServer
// 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	For Each String IN Metadata.DocumentJournals.ProductionDocuments.RegisteredDocuments Do
		Items.DocumentType.ChoiceList.Add(String.Synonym, String.Synonym);
		DocumentTypes.Add(String.Synonym, String.Name);
	EndDo;
	
	// Setting the method of structural unit selection depending on FO.
	If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get()
		AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
		Items.Warehouse.ListChoiceMode = True;
		Items.Warehouse.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		Items.Warehouse.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
	EndIf;
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company				 		= Settings.Get("Company");
	DocumentTypePresentation 		= Settings.Get("DocumentTypePresentation");
	Warehouse				 			= Settings.Get("Warehouse");
	Responsible		 			= Settings.Get("Responsible");
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	SmallBusinessClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	SmallBusinessClientServer.SetListFilterItem(List, "Warehouse", Warehouse, ValueIsFilled(Warehouse));
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", Responsible, ValueIsFilled(Responsible));
	
EndProcedure // OnLoadDataFromSettingsAtServer()

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
// Procedure - event handler OnChange of attribute Warehouse.
// 
Procedure WarehouseOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Warehouse", Warehouse, ValueIsFilled(Warehouse));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute Responsible.
// 
Procedure ResponsibleOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", Responsible, ValueIsFilled(Responsible));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company attribute.
// 
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ValueIsFilled(DocumentType) Then
		
		Cancel = True;
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("StructuralUnit", Warehouse);
		ParametersStructure.Insert("Division", Warehouse);
		ParametersStructure.Insert("Company", Company);
		
		OpenForm("Document." + DocumentType + ".ObjectForm", New Structure("FillingValues", ParametersStructure));
		
	EndIf; 
	
EndProcedure





















