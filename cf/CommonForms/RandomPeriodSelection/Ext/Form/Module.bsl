
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
		CommonUseClientServer.MessageToUser(NStr("en='Period start date is more than the period end date';ru='Дата начала периода больше чем дата окончания периода'"), , "BeginOfPeriod");
		Return;
	EndIf;
	
	ChoiceResult = New Structure("PeriodStart, PeriodEnd, ItemName");
	FillPropertyValues(ChoiceResult, ThisObject);
	
	NotifyChoice(ChoiceResult);
EndProcedure

#EndRegion
