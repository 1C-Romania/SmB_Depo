
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.BackgroundJobProperties = Undefined Then
		
		BackgroundJobProperties = ScheduledJobsService
			.GetBackgroundJobProperties(Parameters.ID);
		
		If BackgroundJobProperties = Undefined Then
			Raise(NStr("en = 'Background job has not been found.'"));
		EndIf;
		
		UserMessagesAndErrorDetails = ScheduledJobsService
			.MessagesAndDescriptionsOfBackgroundJobErrors(Parameters.ID);
			
		If ValueIsFilled(BackgroundJobProperties.ScheduledJobID) Then
			
			ScheduledJobID
				= BackgroundJobProperties.ScheduledJobID;
			
			ScheduledJobDescription
				= ScheduledJobsService.ScheduledJobPresentation(
					BackgroundJobProperties.ScheduledJobID);
		Else
			ScheduledJobDescription  = ScheduledJobsService.TextUndefined();
			ScheduledJobID = ScheduledJobsService.TextUndefined();
		EndIf;
	Else
		BackgroundJobProperties = Parameters.BackgroundJobProperties;
		FillPropertyValues(
			ThisObject,
			BackgroundJobProperties,
			"UserMessagesAndErrorDetails,
			|ScheduledJobID,
			|ScheduledJobDescription");
	EndIf;
	
	FillPropertyValues(
		ThisObject,
		BackgroundJobProperties,
		"ID,
		|Key,
		|Description,
		|Begin,
		|End,
		|Location,
		|Status,
		|MethodName");
		
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject);
	
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
