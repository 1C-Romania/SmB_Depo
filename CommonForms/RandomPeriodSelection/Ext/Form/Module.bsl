
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	BeginOfPeriod = Parameters.BeginOfPeriod;
	EndOfPeriod  = Parameters.EndOfPeriod;
	ItemName   = Parameters.ItemName;
	
	If Not ValueIsFilled(BeginOfPeriod) Then
		BeginOfPeriod = ReportsClientServer.ReportPeriodStart(Parameters.MinimalPeriod, CurrentSessionDate());
	EndIf;
	
	If Not ValueIsFilled(EndOfPeriod) Then
		EndOfPeriod  = ReportsClientServer.ReportEndOfPeriod(Parameters.MinimalPeriod, CurrentSessionDate());
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	If BeginOfPeriod > EndOfPeriod Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Start date of the period exceeds the end date of the period'"), , "BeginOfPeriod");
		Return;
	EndIf;
	
	ChoiceResult = New Structure("PeriodStart, PeriodEnd, ItemName");
	FillPropertyValues(ChoiceResult, ThisObject);
	
	NotifyChoice(ChoiceResult);
EndProcedure

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
