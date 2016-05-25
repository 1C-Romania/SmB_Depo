﻿#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	PackageIdentifier = Parameters.PackageIdentifier;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("AwaitingPermissionsRequestUse", 5, True);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Cancel(Command)
	
	Close(DialogReturnCode.Cancel);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure AwaitingPermissionsRequestUse()
	
	Result = RequestProcessorResults(PackageIdentifier);
	
	If Result = Undefined Then
		AttachIdleHandler("AwaitingPermissionsRequestUse", 5, True);
	Else
		
		If Result Then
			
			Close(DialogReturnCode.OK);
			
		Else
			
			Close(DialogReturnCode.Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function RequestProcessorResults(Val PackageIdentifier)
	
	Result = WorkInSafeModeServiceSaaS.PackageProcessingResult(PackageIdentifier);
	
	If ValueIsFilled(Result) Then
		
		If Result = Enums.QueryProcessingResultsForExternalResourcesUseSaaS.QueryApproved Then
			Return True;
		Else
			Return False;
		EndIf;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
EndFunction

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
