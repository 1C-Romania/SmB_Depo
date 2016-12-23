
#Region FormVariables
	
&AtClient
Var IdleHandlerParameters;

&AtClient
Var LongOperationForm;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Query = New Query("SELECT TOP 1 * FROM Catalog.Banks AS Banks WHERE Banks.ManualChanging <> 2");
	QueryExecutionResult = Query.Execute();
	
	BanksHaveBeenUpdatedFromClassifier = Not QueryExecutionResult.IsEmpty();
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	//--> 15.12.2016 Switch off while work with classifier is not ready
	Return;
	//<--
	Cancel = True;
	
	QuestionText = NStr("en='There is an option to select bank from the classifier.
		|Select?';ru='Есть возможность подобрать банк из классификатора.
		|Подобрать?'");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IsFolder", Group);
	NotifyDescription = New NotifyDescription("DetermineBankPickNeedFromClassifier", ThisObject, AdditionalParameters);
	
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure PickFromClassifier(Command)
	
	FormParameters = New Structure("CloseOnChoice, Multiselect", False, True);
	OpenForm("Catalog.RFBankClassifier.ChoiceForm", FormParameters, ThisForm);

EndProcedure

&AtClient
Procedure UpdateFromClassifier(Command)
	
	If Not BanksHaveBeenUpdatedFromClassifier Then
		
		QuestionText = NStr("en='ATTENTION!
		|All banks will be updated from the classifier. If bank data was changed manually, such changes could be lost.
		|To disable automatic update for the bank in future, it is necessary to select the manual modification check box (command ""Edit"").
		|Continue?';ru='ВНИМАНИЕ!
		|Произойдет обновление всех банков из классификатора. Если данные банков изменялись вручную, то изменения могут быть утеряны.
		|В дальнейшем, для исключения банка из автоматического обновления, необходимо включить признак ручного изменения (команда ""Изменить"").
		|Продолжить?'");
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("UpdateFromClassifierEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0 , DialogReturnCode.No);
        Return;
		
	EndIf;
	
	UpdateFromClassifierFragment();
EndProcedure

&AtClient
Procedure ChangeSelected(Command)
	
	GroupObjectsChangeClient.ChangeSelected(Items.List);

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(JobID) Then
			LongActionsClient.CloseLongOperationForm(LongOperationForm);
			StructureDataAtClient = ImportPreparedData();
			ImportPreparedDataAtClient(StructureDataAtClient);
		Else
			LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution", 
				IdleHandlerParameters.CurrentInterval, 
				True);
		EndIf;
	Except
		LongActionsClient.CloseLongOperationForm(LongOperationForm);
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtClient
Procedure ImportPreparedDataAtClient(DataStructure)
	
	If TypeOf(DataStructure) <> Type("Structure") Then
		Return;
	EndIf;
	
	If DataStructure.Property("SuccessfullyExecuted") Then
		
		NotificationText = NStr("en='Banks are updated from classifier';ru='Банки обновлены из классификатора'");
		ShowUserNotification("Update",, NotificationText);
		
	EndIf;
	
	Notify("RefreshAfterAdd");
	
EndProcedure

&AtServer
Function ImportPreparedData()
	
	StructureDataAtClient = New Structure();
	
	DataStructure = GetFromTempStorage(StorageAddress);
	If TypeOf(DataStructure) <> Type("Structure") Then
		Return Undefined;
	EndIf;
	
	If DataStructure.Property("SuccessfullyUpdated") Then
		StructureDataAtClient.Insert("SuccessfullyUpdated", DataStructure.SuccessfullyUpdated);
	EndIf;
	
	Return StructureDataAtClient;
	
EndFunction

&AtServer
Function RunOnServer(FileInfobase)
	
	ParametersStructure = New Structure();
	
	If FileInfobase Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		Catalogs.Banks.RefreshBanksFromClassifier(ParametersStructure, StorageAddress);
		Result = New Structure("JobCompleted", True);
	Else
		BackgroundJobDescription = NStr("en='Update of the banks from classifier';ru='Обновление банков из классификатора'");
		Result = LongActions.ExecuteInBackground(
			UUID, 
			"Catalogs.Banks.RefreshBanksFromClassifier", 
			ParametersStructure, 
			BackgroundJobDescription);
			
		StorageAddress       = Result.StorageAddress;
		JobID = Result.JobID;
	EndIf;
	
	If Result.JobCompleted Then
		Result.Insert("StructureDataClient", ImportPreparedData());
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshAfterAdd" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateFromClassifierEnd(Result1, AdditionalParameters) Export
    
    Response = Result1;
    If Response = DialogReturnCode.No Then
        
        Return;
        
    EndIf;
    
    
    UpdateFromClassifierFragment();

EndProcedure

&AtClient
Procedure UpdateFromClassifierFragment()
    
    Var FileInfobase, ConnectTimeoutHandler, Result;
    
    FileInfobase = StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase;
    Result  = RunOnServer(FileInfobase);
    
    If Not Result.JobCompleted Then
        
        // Handler will be connected until the background job is completed
        ConnectTimeoutHandler = Not FileInfobase AND ValueIsFilled(JobID);
        If ConnectTimeoutHandler Then
            LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
            AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
            LongOperationForm = LongActionsClient.OpenLongOperationForm(ThisForm, JobID);
        EndIf;
        
    Else
        ImportPreparedDataAtClient(Result.StructureDataClient);
    EndIf;

EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the prompt result about selecting the bank from classifier
//
//
Procedure DetermineBankPickNeedFromClassifier(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		FormParameters = New Structure("ChoiceMode, CloseOnChoice, Multiselect", True, True, True);
		OpenForm("Catalog.RFBankClassifier.ChoiceForm", FormParameters, ThisForm);
		
	Else
		
		If AdditionalParameters.IsFolder Then
			
			OpenForm("Catalog.Banks.FolderForm", New Structure("IsFolder",True), ThisObject);
			
		Else
			
			OpenForm("Catalog.Banks.ObjectForm");
			
		EndIf;
		
	EndIf;
	
EndProcedure // DetermineBankPickNeedFromClassifier()

#EndRegion















