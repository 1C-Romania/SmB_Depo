&AtClient
Var EnableClosure;
&AtClient
Var WaitingEnd;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Duration = Parameters.Duration;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	EnableClosure = False;
	
	If Duration > 0 Then
		WaitingEnd = False;
		AttachIdleHandler("AfterSettingsUsageAwaitingInCluster", Duration, True);
	Else
		WaitingEnd = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not EnableClosure Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure AfterSettingsUsageAwaitingInCluster()
	
	EnableClosure = True;
	Close(DialogReturnCode.OK);
	
EndProcedure

#EndRegion