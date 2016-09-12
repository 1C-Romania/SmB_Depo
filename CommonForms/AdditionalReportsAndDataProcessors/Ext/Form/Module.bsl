&AtClient
Var HandlerParameters;

&AtClient
Var ExecuteCommand;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("WindowOpeningMode") Then
		ThisObject.WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	
	If ValueIsFilled(Parameters.SectionName)
		AND Parameters.SectionName <> AdditionalReportsAndDataProcessorsClientServer.DesktopID() Then
		SectionReference = CommonUse.MetadataObjectID(Metadata.Subsystems.Find(Parameters.SectionName));
	EndIf;
	
	KindOfDataProcessors = AdditionalReportsAndDataProcessors.GetDataProcessorKindByKindStringPresentation(Parameters.Kind);
	
	If KindOfDataProcessors = Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling Then
		ThisIsAppointedDataProcessors = True;
		Title = NStr("en = 'Filling objects commands'");
	ElsIf KindOfDataProcessors = Enums.AdditionalReportsAndDataProcessorsKinds.Report Then
		ThisIsAppointedDataProcessors = True;
		AreReports = True;
		Title = NStr("en = 'Reports'");
	ElsIf KindOfDataProcessors = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		ThisIsAppointedDataProcessors = True;
		Title = NStr("en = 'Additional print forms'");
	ElsIf KindOfDataProcessors = Enums.AdditionalReportsAndDataProcessorsKinds.CreatingLinkedObjects Then
		ThisIsAppointedDataProcessors = True;
		Title = NStr("en = 'Commands of creating the linked objects'");
	ElsIf KindOfDataProcessors = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalInformationProcessor Then
		ThisIsGlobalDataProcessors = True;
		Title = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Additional data processors (%1)'"), 
			AdditionalReportsAndDataProcessors.PresentationOfSection(SectionReference));
	ElsIf KindOfDataProcessors = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		ThisIsGlobalDataProcessors = True;
		AreReports = True;
		Title = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Additional reports (%1)'"), 
			AdditionalReportsAndDataProcessors.PresentationOfSection(SectionReference));
	EndIf;
	
	If Parameters.Property("Title") Then
		Title = Parameters.Title;
	EndIf;
	
	If ThisIsAppointedDataProcessors Then
		Items.CustomizeList.Visible = False;
		
		DestinationObjects.LoadValues(Parameters.DestinationObjects.UnloadValues());
		
		OwnerFormName = Parameters.FormName;
		InformationAboutOwner = AdditionalReportsAndDataProcessorsReUse.AssignedObjectFormParameters(OwnerFormName);
		
		If TypeOf(InformationAboutOwner) = Type("FixedStructure") Then
			ParentRef  = InformationAboutOwner.ParentRef;
			ThisIsObjectForm = InformationAboutOwner.ThisIsObjectForm;
		Else
			MetadataOfParent = Metadata.FindByType(TypeOf(DestinationObjects[0].Value));
			ParentRef  = CommonUse.MetadataObjectID(MetadataOfParent);
			ThisIsObjectForm = False;
		EndIf;
	EndIf;
	
	FillTableOfDataProcessors();
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	If ValueSelected = "ExecutedMyReportsAndDataProcessorsCustomization" Then
		FillTableOfDataProcessors();
	EndIf;
EndProcedure

&AtClient
Procedure OnClose()
	If BackgroundJobCheckExecutionOnClose Then
		BackgroundJobCheckExecutionOnClose = False;
		DetachIdleHandler("CheckBackgroundJobExecution");
		
		Result = CheckBackgroundJobExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, True);
		If Result.Completed OR Result.ExceptionCalled Then
			ShowProcessingExecutionResult(Result, False);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersCommandTable

&AtClient
Procedure TableOfCommandsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	RunDataProcessorByParameters();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RunDataProcessor(Command)
	
	RunDataProcessorByParameters()
	
EndProcedure

&AtClient
Procedure CustomizeList(Command)
	Open = New Structure("Name, Parameters, Owner, Uniqueness, Window");
	
	Open.Name = "CommonForm.SetMyReportsAndDataProcessors";
	Open.Owner = ThisObject;
	Open.Uniqueness = False;
	
	Open.Parameters = New Structure("KindOfDataProcessors, ThisIsGlobalDataProcessors, CurrentSection");
	Open.Parameters.KindOfDataProcessors           = KindOfDataProcessors;
	Open.Parameters.ThisIsGlobalDataProcessors = ThisIsGlobalDataProcessors;
	Open.Parameters.CurrentSection          = SectionReference;
	
	OpenForm(Open.Name, Open.Parameters, Open.Owner, Open.Uniqueness, Open.Window);
EndProcedure

&AtClient
Procedure CancelDataProcessorExecution(Command)
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillTableOfDataProcessors()
	Query = AdditionalReportsAndDataProcessors.NewQueryByAvailableCommands(KindOfDataProcessors, ?(ThisIsGlobalDataProcessors, SectionReference, ParentRef), ThisIsObjectForm);
	
	ResultTable = Query.Execute().Unload();
	
	ValueToFormAttribute(ResultTable, "CommandTable");
EndProcedure

&AtClient
Procedure RunDataProcessorByParameters()
	DataProcessorData = Items.CommandTable.CurrentData;
	If DataProcessorData = Undefined Then
		Return;
	EndIf;
	
	//( elmi Lost in translation - fixed for  #17
	//ExecuteCommand = New Structure(
	//	"Refs, Presentation, Identifier, StartVariant, ShowAlert, Modifier, DestinationObjects, IsReport, Kind");
	ExecuteCommand = New Structure(
		"Ref, Presentation, ID, StartVariant, ShowAlert, Modifier, DestinationObjects, IsReport, Type");
	//) elmi 	
		
	FillPropertyValues(ExecuteCommand, DataProcessorData);
	If Not ThisIsGlobalDataProcessors Then
		ExecuteCommand.DestinationObjects = DestinationObjects.UnloadValues();
	EndIf;
	ExecuteCommand.IsReport = AreReports;
	ExecuteCommand.Type = KindOfDataProcessors;
	
	If DataProcessorData.StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.FormOpening") Then
		
		AdditionalReportsAndDataProcessorsClient.RunOpenOfProcessingForm(ExecuteCommand, FormOwner, ExecuteCommand.DestinationObjects);
		Close();
		
	ElsIf DataProcessorData.StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.CallOfClientMethod") Then
		
		AdditionalReportsAndDataProcessorsClient.RunClientMethodOfDataProcessor(ExecuteCommand, FormOwner, ExecuteCommand.DestinationObjects);
		Close();
		
	ElsIf KindOfDataProcessors = PredefinedValue("Enum.AdditionalReportsAndDataProcessorsKinds.PrintForm")
		AND DataProcessorData.Modifier = "MXLPrint" Then
		
		AdditionalReportsAndDataProcessorsClient.ExecutePrintFormOpening(ExecuteCommand, FormOwner, ExecuteCommand.DestinationObjects);
		Close();
		
	ElsIf DataProcessorData.StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.CallOfServerMethod")
		Or DataProcessorData.StartVariant = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ScriptInSafeMode") Then
		
		// Change of the form items
		Items.ExplanatoryDecoration.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Command ""%1"" is being executed...'"),
			DataProcessorData.Presentation);
		Items.Pages.CurrentPage = Items.DataProcessorExecutionPage;
		Items.PagesCommandBars.CurrentPage = Items.DataProcessorExecutionPageCommandBarPage;
		
		// Server call only after the form transition to the consistent state.
		AttachIdleHandler("RunServerMethodOfDataProcessor", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RunServerMethodOfDataProcessor()
	BackgroundJobCheckExecutionOnClose = True;
	
	ServerCallParameters = New Structure("AdditionalInformationProcessorRef, CommandID, DestinationObjects");
	ServerCallParameters.AdditionalInformationProcessorRef = ExecuteCommand.Ref;
	ServerCallParameters.CommandID   = ExecuteCommand.ID;
	ServerCallParameters.DestinationObjects      = ExecuteCommand.DestinationObjects;
	
	Result = ExecuteProcessingServerMethodAtServer(ServerCallParameters);
	
	If Result.Completed OR Result.ExceptionCalled Then
		ShowProcessingExecutionResult(Result, True);
	Else
		LongActionsClient.InitIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("CheckBackgroundJobExecution", 1, True);
	EndIf;
EndProcedure

&AtServer
Function ExecuteProcessingServerMethodAtServer(ServerCallParameters)
	Result = New Structure("Completed, ExceptionCalled, Value", False, False, Undefined);
	
	Try
		BackgroundJobResult = LongActions.ExecuteInBackground(
			UUID,
			"AdditionalReportsAndDataProcessors.RunCommand", 
			ServerCallParameters, 
			NStr("en = 'Additional reports and data processors: The execution of the server processing method'"));
		
		If BackgroundJobResult.JobCompleted Then
			Result.Completed = True;
			Result.Value  = GetFromTempStorage(BackgroundJobResult.StorageAddress);
		Else
			BackgroundJobID  = BackgroundJobResult.JobID;
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
		EndIf;
	Except
		Result.ExceptionCalled = True;
		AdditionalReportsAndDataProcessors.WriteError(
			ServerCallParameters.AdditionalInformationProcessorRef,
			NStr("en = 'Command %1: Execution error:%2'"),
			ServerCallParameters.CommandID,
			Chars.LF + DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Result;
EndFunction

&AtClient
Procedure ShowProcessingExecutionResult(Result, CloseThisForm)
	// Adding a notification in the execution result (if required).
	ExecutionResult = ?(Result = Undefined, Undefined, Result.Value);
	If ExecuteCommand.ShowAlert Then
		If ExecutionResult = Undefined Then
			ExecutionResult = StandardSubsystemsClientServer.NewExecutionResult();
		EndIf;
		If Not ExecutionResult.Property("OutputNotification") Then
			ExecutionResult.Insert("OutputNotification", New Structure("Use, Title, Text, Picture", False));
		EndIf;
		If ExecutionResult.OutputNotification.Use <> True Then
			ExecutionResult.OutputNotification.Use = True;
			ExecutionResult.OutputNotification.Title = NStr("en = 'Command executed'");
			ExecutionResult.OutputNotification.Text = ExecuteCommand.Presentation;
		EndIf;
	EndIf;
	
	If Result <> Undefined AND Result.ExceptionCalled Then
		// Go to the page with the list of commands.
		Items.Pages.CurrentPage = Items.PageOpenProcessing;
		Items.PagesCommandBars.CurrentPage = Items.PageOpenDataProcessorPageCommandBar;
		// Output of the error message.
		WarningText = NStr("en = 'Failed to execute the ""%1"" command.
		|Look for details in event log.'");
		WarningText = StrReplace(WarningText, "%1", ExecuteCommand.Presentation);
		ShowMessageBox(, WarningText);
		// Cancel closing.
		Return;
	EndIf;
	
	// Update the owner form
	If ThisIsObjectForm Then
		Try
			FormOwner.Read();
		Except
			// The action is not required.
		EndTry;
	EndIf;
	
	// Background job has already completed.
	BackgroundJobCheckExecutionOnClose = False;
	
	// Close current form
	If CloseThisForm = True Then
		Close();
	EndIf;
	
	// Output of the execution result.
	StandardSubsystemsClient.ShowExecutionResult(FormOwner, ExecutionResult);
EndProcedure

&AtClient
Procedure CheckBackgroundJobExecution()
	Result = CheckBackgroundJobExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress);
	If Result.Completed OR Result.ExceptionCalled Then
		ShowProcessingExecutionResult(Result, True);
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("CheckBackgroundJobExecution", HandlerParameters.CurrentInterval, True);
	EndIf;
EndProcedure

&AtServerNoContext
Function CheckBackgroundJobExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, Cancel = False)
	Result = New Structure("Completed, ExceptionCalled, Value", False, False, Undefined);
	Try
		If LongActions.JobCompleted(BackgroundJobID) Then
			Result.Completed = True;
			Result.Value  = GetFromTempStorage(BackgroundJobStorageAddress);
		EndIf;
	Except
		Result.ExceptionCalled = True;
	EndTry;
	If Cancel Then
		LongActions.CancelJobExecution(BackgroundJobID);
	EndIf;
	Return Result;
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
