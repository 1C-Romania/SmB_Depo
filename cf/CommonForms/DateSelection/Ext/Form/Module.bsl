&AtClient
Var ActionSelected;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	ActionSelected = False;
	
	InitialValue = Parameters.InitialValue;
	
	If Not ValueIsFilled(InitialValue) Then
		InitialValue = CurrentSessionDate();
	EndIf;
	
	Parameters.Property("BeginOfRepresentationPeriod", Items.Calendar.BeginOfRepresentationPeriod);
	Parameters.Property("EndOfRepresentationPeriod", Items.Calendar.EndOfRepresentationPeriod);
	
	Calendar = InitialValue;
	
	Parameters.Property("Title", Title);
	
	If Parameters.Property("ExplanationText") Then
		Items.ExplanationText.Title = Parameters.ExplanationText;
	Else
		Items.ExplanationText.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If ActionSelected <> True Then
		NotifyChoice(Undefined);
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

&AtClient
Procedure CalendarSelection(Item, SelectedDate)
	
	ActionSelected = True;
	NotifyChoice(SelectedDate);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	SelectedDates = Items.Calendar.SelectedDates;
	
	If SelectedDates.Count() = 0 Then
		ShowMessageBox(,NStr("en='Date is not selected.';ru='Дата не выбрана.'"));
		Return;
	EndIf;
	
	ActionSelected = True;
	NotifyChoice(SelectedDates[0]);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ActionSelected = True;
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

