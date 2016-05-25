
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterEmployee			= Settings.Get("FilterEmployee");
	FilterCompany 		= Settings.Get("FilterCompany");
	FilterDivision 		= Settings.Get("FilterDivision");
	FilterRegistrationPeriod 	= Settings.Get("FilterRegistrationPeriod"); 
	
	SmallBusinessClientServer.SetListFilterItem(List, "AccrualsDeductions.Employee", FilterEmployee, ValueIsFilled(FilterEmployee));
	SmallBusinessClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	SmallBusinessClientServer.SetListFilterItem(List, "StructuralUnit", FilterDivision, ValueIsFilled(FilterDivision));
	SmallBusinessClientServer.SetListFilterItem(List, "RegistrationPeriod", FilterRegistrationPeriod, ValueIsFilled(FilterRegistrationPeriod));
	
	RegistrationPeriodPresentation = Format(FilterRegistrationPeriod, "DF='MMMM yyyy'");
	
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ManagedForm")
		AND Find(ChoiceSource.FormName, "CalendarForm") > 0 Then
		
		FilterRegistrationPeriod = EndOfDay(ValueSelected);
		SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
		SmallBusinessClientServer.SetListFilterItem(List, "RegistrationPeriod", FilterRegistrationPeriod, ValueIsFilled(FilterRegistrationPeriod));
		
	EndIf;
	
EndProcedure // ChoiceProcessing()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS

&AtClient
Procedure FilterEmployeeOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "AccrualsDeductions.Employee", FilterEmployee, ValueIsFilled(FilterEmployee));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterCompanyOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterDivision.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterDivisionOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "StructuralUnit", FilterDivision, ValueIsFilled(FilterDivision));
EndProcedure

&AtClient
//Procedure event handler of field management RegistrationPeriod
//
Procedure FilterRegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	SmallBusinessClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
	SmallBusinessClientServer.SetListFilterItem(List, "RegistrationPeriod", FilterRegistrationPeriod, ValueIsFilled(FilterRegistrationPeriod));
	
EndProcedure //FilterRegistrationPeriodTuning()

&AtClient
//Procedure event handler of field choice start RegistrationPeriod
//
Procedure FilterRegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(FilterRegistrationPeriod), FilterRegistrationPeriod, SmallBusinessReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.CalendarForm", SmallBusinessClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure //FilterRegistrationPeriodStartChoice()

&AtClient
//Procedure event handler of field data cleaning RegistrationPeriod
//
Procedure FilterRegistrationPeriodClearing(Item, StandardProcessing)
	
	FilterRegistrationPeriod = Undefined;
	SmallBusinessClient.OnChangeRegistrationPeriod(ThisForm);
	SmallBusinessClientServer.SetListFilterItem(List, "RegistrationPeriod", FilterRegistrationPeriod, ValueIsFilled(FilterRegistrationPeriod));
	
EndProcedure //FilterRegistrationPeriodClearing()

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion



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
