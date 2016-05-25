
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Try
		
		If Not Users.InfobaseUserWithFullAccess() Then
			Raise NStr("en = 'You have no right to end session!'");
		EndIf;
		
		SessionNumber = Parameters.SessionNumber;
		
		GotoToAssistantStep(1);
		
	Except
		
		ProcessException(BriefErrorDescription(ErrorInfo()));
		
	EndTry;
	
EndProcedure

&AtClient
Function StartSessionEnd() Export
	
	If IsBlankString(Password) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'No password is specified to access the service.'"), ,
			"Password"
		);
		
		Return False;
		
	Else
		
		Try
			
			StartSessionAtServerEnd();
			AttachIdleHandler("Attachable_CheckBackgroundJobExecution", 5, True);
			
			Return True;
			
		Except
			
			ProcessException(BriefErrorDescription(ErrorInfo()));
			
			Return False;
			
		EndTry;
		
	EndIf;
	
EndFunction

&AtServer
Procedure StartSessionAtServerEnd()
	
	JobParameters = New Array();
	JobParameters.Add(SessionNumber);
	JobParameters.Add(Password);
	
	Task = BackgroundJobs.Execute(
		"RemoteAdministrationSTLService.DataAreaSessionEnd",
		JobParameters,
		,
		NStr("en = 'End the active session'")
	);
	
	JobID = Task.UUID;
	
EndProcedure

&AtClient
Procedure Attachable_CheckBackgroundJobExecution()
	
	Try
		
		If BackGroundJobFinished(JobID) Then 
			
			Close(DialogReturnCode.OK);
			
		Else
			
			AttachIdleHandler("Attachable_CheckBackgroundJobExecution", 2, True);
			
		EndIf;
		
	Except
		
		ProcessException(BriefErrorDescription(ErrorInfo()));
		
	EndTry;
	
EndProcedure

&AtServerNoContext
Function BackGroundJobFinished(JobID)
	
	Task = BackgroundJobs.FindByUUID(JobID);
	
	If Task <> Undefined
		AND Task.Status = BackgroundJobState.Active Then
		Return False;
	EndIf;
	
	If Task = Undefined Then
		
		Raise NStr("en = 'Background job is not found!'");
		
	Else
		
		If Task.Status = BackgroundJobState.Failed Then
			
			Raise BriefErrorDescription(Task.ErrorInfo);
			
		ElsIf Task.Status = BackgroundJobState.Canceled Then
			
			Raise NStr("en = 'Background job is canceled by administrator!'");
			
		Else
			
			Return True;
			
		EndIf;
		
	EndIf;
	
EndFunction


&AtClient
Procedure Next(Command)
	
	If ExecuteTransitionBetweenStepsHandler(HandlerToMoveFromCurrentStep) Then
		GotoToAssistantStep(CurrentStep + 1);
	EndIf;
	
EndProcedure

&AtClient
Function ExecuteTransitionBetweenStepsHandler(Val Handler)
	
	Result = False;
	
	If ValueIsFilled(Handler) Then
		
		Try
			
			If Handler = "StartSessionEnd" Then
				Result = StartSessionEnd();
			EndIf;
			
		Except
			
			ProcessException(BriefErrorDescription(ErrorInfo()));
			
		EndTry;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure ProcessException(Val ErrorMessage)
	
	ErrorText = ErrorMessage;
	GotoToAssistantStep(3);
	
EndProcedure

&AtServer
Function GotoToAssistantStep(Val Step)
	
	Script = AssistantScript();
	
	StepDescription = Script.Find(Step, "StepNumber");
	Items.GroupPages.CurrentPage = Items[StepDescription.Page];
	Items.GroupPageCommands.CurrentPage = Items[StepDescription.CommandsPage];
	
	HandlerToMoveFromCurrentStep = StepDescription.Handler;
	CurrentStep = Step;
	
EndFunction

&AtServer
Function AssistantScript()
	
	Result = New ValueTable();
	
	Result.Columns.Add("StepNumber", New TypeDescription("Number"));
	Result.Columns.Add("Page", New TypeDescription("String"));
	Result.Columns.Add("CommandsPage", New TypeDescription("String"));
	Result.Columns.Add("Handler", New TypeDescription("String"));
	
	// Enter password
	NewRow = Result.Add();
	NewRow.StepNumber = 1;
	NewRow.Page = Items.PageEnterPassword.Name;
	NewRow.CommandsPage = Items.CommandPageEnterPassword.Name;
	NewRow.Handler = "StartSessionEnd";
	
	// Waiting for end
	NewRow = Result.Add();
	NewRow.StepNumber = 2;
	NewRow.Page = Items.PageWait.Name;
	NewRow.CommandsPage = Items.CommandPageWait.Name;
	
	// View error
	NewRow = Result.Add();
	NewRow.StepNumber = 3;
	NewRow.Page = Items.PageError.Name;
	NewRow.CommandsPage = Items.PageCommandsError.Name;
	
	Return Result;
	
EndFunction








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
