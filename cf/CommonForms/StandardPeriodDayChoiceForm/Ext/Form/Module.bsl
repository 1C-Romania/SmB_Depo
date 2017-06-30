#Region FormHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	BeginOfPeriod = Parameters.BeginOfPeriod;
	EndOfPeriod  = Parameters.EndOfPeriod;
	If BegOfDay(BeginOfPeriod) = BegOfDay(EndOfPeriod) Then
		Day = BeginOfPeriod;
	Else
		Day = CurrentSessionDate();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsHandlers

&AtClient
Procedure DayOnChange(Item)
	
	AttachIdleHandler("Attached_DayOnChange", 0.1, True);
	
EndProcedure

&AtClient
Procedure Attached_DayOnChange()

	ChoiceResult = New Structure("BeginOfPeriod,EndOfPeriod", BegOfDay(Day), EndOfDay(Day));
	Close(ChoiceResult);

EndProcedure

#EndRegion