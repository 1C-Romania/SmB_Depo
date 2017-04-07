//////////////////////////////////////////////////////////////////////////////// 
// FORM EVENT HANDLERS
//

&AtServer
// Procedure - form event handler OnCreateAtServer
// 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		
		Return;
		
	EndIf;
	
	For Each String IN Metadata.DocumentJournals.PayrollDocuments.RegisteredDocuments Do
		Items.DocumentType.ChoiceList.Add(String.Synonym, String.Synonym);
		DocumentTypes.Add(String.Synonym, String.Name);
	EndDo;
	
	List.Parameters.SetParameterValue("Employee", Employee);
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company				 		= Settings.Get("Company");
	DocumentTypePresentation 		= Settings.Get("DocumentTypePresentation");
	Department			 		= Settings.Get("Department");
	Employee				 		= Settings.Get("Employee");
	RegistrationPeriod 				= Settings.Get("RegistrationPeriod");
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	SmallBusinessClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	SmallBusinessClientServer.SetListFilterItem(List, "Department", Department, ValueIsFilled(Department));
	SmallBusinessClientServer.SetListFilterItem(List, "RegistrationPeriod", RegistrationPeriod, ValueIsFilled(RegistrationPeriod));
	List.Parameters.SetParameterValue("Employee", Employee);
	
	RegistrationPeriodPresentation = Format(RegistrationPeriod, "DF='MMMM yyyy'");
	
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ManagedForm")
		AND Find(ChoiceSource.FormName, "CalendarForm") > 0 Then
		
		RegistrationPeriod = EndOfDay(ValueSelected);
		SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
		SmallBusinessClientServer.SetListFilterItem(List, "RegistrationPeriod", RegistrationPeriod, ValueIsFilled(RegistrationPeriod));
		
	EndIf;
	
EndProcedure // ChoiceProcessing()


//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS OF FORM ATTRIBUTES 
//

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
// Procedure - event handler Management of attribute RegistrationPeriod.
//
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	SmallBusinessClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
	SmallBusinessClientServer.SetListFilterItem(List, "RegistrationPeriod", RegistrationPeriod, ValueIsFilled(RegistrationPeriod));
	
EndProcedure //RegistrationPeriodTuning()

&AtClient
// Procedure - event handler StartChoice of attribute RegistrationPeriod.
//
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(RegistrationPeriod), RegistrationPeriod, SmallBusinessReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.CalendarForm", SmallBusinessClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure //RegistrationPeriodStartChoice()

&AtClient
// Procedure - event handler Clean of attribute RegistrationPeriod.
//
Procedure RegistrationPeriodClearing(Item, StandardProcessing)
	
	RegistrationPeriod = Undefined;
	SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
	SmallBusinessClientServer.SetListFilterItem(List, "RegistrationPeriod", RegistrationPeriod, ValueIsFilled(RegistrationPeriod));
	
EndProcedure //RegistrationPeriodClearing()

&AtClient
// Procedure - event handler OnChange of attribute Department.
// 
Procedure DepartmentOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Department", Department, ValueIsFilled(Department));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company attribute.
// 
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute Employee.
// 
Procedure EmployeeOnChange(Item)
	
	List.Parameters.SetParameterValue("Employee", Employee);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ValueIsFilled(DocumentType) Then
		
		Cancel = True;
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("StructuralUnit", Department);
		ParametersStructure.Insert("RegistrationPeriod", RegistrationPeriod);
		ParametersStructure.Insert("Company", Company);
		
		OpenForm("Document." + DocumentType + ".ObjectForm", New Structure("FillingValues", ParametersStructure));
		
	EndIf; 
	
EndProcedure







