
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	AccumulationRegistersPeriod = EndOfPeriod(AddMonth(CurrentSessionDate(), -1));
	PeriodForAccountingRegisters = EndOfPeriod(CurrentSessionDate());
	
	Items.PeriodForAccountingRegisters.Enabled  = Parameters.AccountingReg;
	Items.AccumulationRegistersPeriod.Enabled = Parameters.AccumulationReg;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PeriodForRegistersAccumulationOnChange(Item)
	
	AccumulationRegistersPeriod = EndOfPeriod(AccumulationRegistersPeriod);
	
EndProcedure

&AtClient
Procedure PeriodForAccountingRegistersOnChange(Item)
	
	PeriodForAccountingRegisters = EndOfPeriod(PeriodForAccountingRegisters);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New Structure("AccumulationRegistersPeriod, PeriodForAccountingRegisters");
	FillPropertyValues(ChoiceResult, ThisObject);
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClientAtServerNoContext
Function EndOfPeriod(Date)
	
	Return EndOfDay(EndOfMonth(Date));
	
EndFunction

#EndRegion
