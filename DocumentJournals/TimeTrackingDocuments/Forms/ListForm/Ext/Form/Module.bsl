
//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

&AtServer
// Procedure - form event handler OnCreateAtServer
// 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	For Each String IN Metadata.DocumentJournals.TimeTrackingDocuments.RegisteredDocuments Do
		Items.DocumentType.ChoiceList.Add(String.Synonym, String.Synonym);
		DocumentTypes.Add(String.Synonym, String.Name);
	EndDo;
	
	List.Parameters.SetParameterValue("Customer", Customer);
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure // OnCreateAtServer()

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company				 		= Settings.Get("Company");
	DocumentTypePresentation 		= Settings.Get("DocumentTypePresentation");
	Employee			 			= Settings.Get("Employee");
	Customer			 			= Settings.Get("Customer");
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
    SmallBusinessClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	SmallBusinessClientServer.SetListFilterItem(List, "Employee", Employee, ValueIsFilled(Employee));
	SmallBusinessClientServer.SetListFilterItem(List, "Customer", Customer, ValueIsFilled(Customer));
	List.Parameters.SetParameterValue("Customer", Customer);
	
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtClient
// Procedure - event handler OnChange of attribute Employee.
// 
Procedure EmployeeOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Employee", Employee, ValueIsFilled(Employee));
	
EndProcedure // EmployeeOnChange()

&AtClient
// Procedure - event handler OnChange of attribute Customer.
//
Procedure ConsumerOnChange(Item)
	
	List.Parameters.SetParameterValue("Customer", Customer);
	SmallBusinessClientServer.SetListFilterItem(List, "Customer", Customer, ValueIsFilled(Customer));
	
EndProcedure // CustomerOnChange()

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
	
EndProcedure // DocumentTypeOnChange()

&AtClient
// Procedure - event handler OnChange of the Company attribute.
//
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure // CompanyOnChange()

&AtClient
// Procedure - event handler ChoiceProcessing of attribute Customer.
//
Procedure ConsumerChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = Type("CatalogRef.CounterpartyContracts") Then
	
		StandardProcessing = False;
		
		SelectedContract = Undefined;

		
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceFormWithCounterparty",,,,,, New NotifyDescription("CustomerChoiceProcessingEnd", ThisObject));
	
	EndIf; 
	
EndProcedure

&AtClient
Procedure CustomerChoiceProcessingEnd(Result, AdditionalParameters) Export
    
    SelectedContract = Result;
    
    If TypeOf(SelectedContract) = Type("CatalogRef.CounterpartyContracts")Then
        Customer = SelectedContract;
        List.Parameters.SetParameterValue("Customer", Customer);
    EndIf;

EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ValueIsFilled(DocumentType) Then
		
		Cancel = True;
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("Employee", Employee);
		ParametersStructure.Insert("Customer", Customer);
		ParametersStructure.Insert("Company", Company);
		
		OpenForm("Document." + DocumentType + ".ObjectForm", New Structure("FillingValues", ParametersStructure));
		
	EndIf; 
	
EndProcedure


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
