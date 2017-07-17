&AtClient
Var IdleHandlerParameters;

&AtClient
Var LongOperationForm;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	//	Buttons and parameters 
	
	If Parameters.Property("Period")
		AND Parameters.Period <> Undefined Then
			
			RadioButton = Parameters.Period;
			BeginOfPeriod = Parameters["BeginOfPeriod"];
			EndOfPeriod  = Parameters["EndOfPeriod"];
			
	Else
		
		RadioButton = "Year";
		BeginOfPeriod = BegOfYear(CurrentDate());
		EndOfPeriod  = EndOfYear(CurrentDate());
		
	EndIf;
	
	Items.CompaniesTable.Enabled = OnlySelectedCompanies;
	
	DocumnetsPosted = 0;
	FailedToPost   = 0;
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetPeriodLabel();
	
EndProcedure // OnOpen()

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure OnlySelectedOrganizationOnChange(Item)
	
	Items.CompaniesTable.Enabled = OnlySelectedCompanies;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF <TABLE NAME> TABLE

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure is called when clicking "Increase period" button on the report form
// 
&AtClient
Procedure ExtendPeriod(Command)
	
	SetPeriod(RadioButton, 1);
	SetPeriodLabel();
	
EndProcedure // ExtendPeriod()

// Procedure is called when clicking "Shortened period" button on the report form
// 
&AtClient
Procedure ShortenPeriod(Command)
	
	SetPeriod(RadioButton, -1);
	SetPeriodLabel();
	
EndProcedure //ShortenPeriod()

&AtClient
Procedure ButtonExecute(Command)
	
	ClearMessages();
	
	If OnlySelectedCompanies = 1 AND Not ValueIsFilled(CompaniesTable) Then
		MessageText = NStr("en='Company list is filled in incorrectly.';ru='Не корректно заполнен список организаций.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	InitializingCommandsDocumentAtClient();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure ShowResultOfReposting()
	
	MessageText = NStr("en='Reposting documents
		| is executed: - documents
		|posted: %1; %2';ru='Выполнено перепроведение документов:
		| - проведено документов: %1;
		|%2'");
	If FailedToPost = 0 Then
		ErrorsMessageBox = NStr("en=' - no errors.';ru=' - ошибок не обнаружено.'");
	Else
		ErrorsMessageBox = NStr("en=' - failed to post documents: %1';ru=' - не удалось провести документов: %1'");
		ErrorsMessageBox = StringFunctionsClientServer.SubstituteParametersInString(
			ErrorsMessageBox, FailedToPost);
	EndIf;
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		MessageText, DocumnetsPosted, ErrorsMessageBox);
		
	ShowMessageBox(Undefined,MessageText);
	
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()

	Try
		If LongOperationForm.IsOpen() 
			AND LongOperationForm.JobID = JobID Then			
			If JobCompleted(JobID) Then
				ImportPreparedDataAtServer();
				LongActionsClient.CloseLongOperationForm(LongOperationForm);
				ShowResultOfReposting();
			Else
				LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
				AttachIdleHandler("Attachable_CheckJobExecution",
					IdleHandlerParameters.CurrentInterval, True);
			EndIf;
		Else
			// Task cancelled
			JobID = Undefined;
		EndIf;
	Except
		LongActionsClient.CloseLongOperationForm(LongOperationForm);
		Raise;
	EndTry;

EndProcedure

&AtClient
Procedure InitializingCommandsDocumentAtClient()
	
	Result = RunOnServer();
	
	If Result = 1 Then
		ShowMessageBox(Undefined,NStr("en='Reposting is already being performed. Await completion.';ru='Перепроведение уже выполняется. Ожидайте завершения.'"));
		Return;
	ElsIf Result = 2 Then
		ShowMessageBox(Undefined,NStr("en='Another user is already performing reposting.';ru='Перепроведение уже выполняется другим пользователем.'"));
		Return;
	EndIf;
	
	If Not Result.JobCompleted Then
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		LongOperationForm = LongActionsClient.OpenLongOperationForm(ThisForm, JobID);
	Else
		ShowResultOfReposting();
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportPreparedDataAtServer()

	DataStructure = GetFromTempStorage(StorageAddress);
	If TypeOf(DataStructure) <> Type("Structure") Then
		Return;
	EndIf;

	If DataStructure.Property("DocumnetsPosted") Then
		DocumnetsPosted = DataStructure.DocumnetsPosted;
	EndIf;
	If DataStructure.Property("FailedToPost") Then
		FailedToPost = DataStructure.FailedToPost;
	EndIf;
	
    DisplayMessagesToUser();
	
	JobID = Undefined;
	UnlockDataForEdit(, UUID);

EndProcedure

&AtServer
Function RunOnServer()
	
	If ValueIsFilled(JobID) 
		AND Not LongActions.JobCompleted(JobID) Then
		Return 1;
	EndIf;
	
	If OnlySelectedCompanies = 0 Then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Companies.Ref AS Company
		|FROM
		|	Catalog.Companies AS Companies";
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			Try
				LockDataForEdit(Selection.Company,, UUID);
			Except
				UnlockDataForEdit(, UUID);
				Return 2;
			EndTry;
		EndDo;
	Else
		SelectedCompanies = New Array;
		For Each ListOfCompanies IN CompaniesTable Do
			If ValueIsFilled(ListOfCompanies.Company) Then
				SelectedCompanies.Add(ListOfCompanies.Company);
				
				Try
					LockDataForEdit(ListOfCompanies.Company,, UUID);
				Except
					UnlockDataForEdit(, UUID);
					Return 2;
				EndTry;
			EndIf;
		EndDo;
	EndIf;
	
	ParametersStructure = New Structure("Company, BeginOfPeriod, EndOfPeriod, WriteErrorsToEventLogMonitor, StopOnError",
		?(OnlySelectedCompanies = 0, Undefined, SelectedCompanies),
		?(ValueIsFilled(BeginOfPeriod), BeginOfPeriod, Undefined),
		?(ValueIsFilled(EndOfPeriod), EndOfPeriod, Undefined),
		True,
		True);
	
	If CommonUse.FileInfobase() Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		DataProcessors.GroupDocumentsReposting.RepostingDocuments(ParametersStructure, StorageAddress);
		Result = New Structure("JobCompleted", True);

	Else
		JobDescription = NStr("en='Group document reposting';ru='Групповое перепроведение документов'");
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.GroupDocumentsReposting.RepostingDocuments",
			ParametersStructure,
			JobDescription);

		StorageAddress       = Result.StorageAddress;
		JobID = Result.JobID;
	EndIf;
	
	If Result.JobCompleted Then
		ImportPreparedDataAtServer();
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure DisplayMessagesToUser()
	
	If CommonUse.FileInfobase() Then
		Return;
	EndIf;
	
	BackgroundJob = BackgroundJobs.FindByUUID(JobID);
	If BackgroundJob <> Undefined Then
		MessagesArray = BackgroundJob.GetUserMessages(True);
		If MessagesArray <> Undefined Then
			For Each Message IN MessagesArray Do
				Message.TargetID = UUID;
				Message.Message();
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Procedure sets the compositing data parameters and period label
// on the form by received parameters
//
// Changeable Parameters composing data:
// Begin of period - date, report generation beginning
// of the period End of period - date, report generation end of the period
//
&AtServer
Procedure SetPeriod(PeriodName, Direction)
	
	BeginOfPeriodValue 		= BegOfDay(CurrentDate());
	ValueEndPeriod	= EndOfDay(CurrentDate());
	
	If PeriodName = "Week" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfWeek(EndOfPeriod + (86400 * 7 * Direction));
		ValueEndPeriod	= EndOfWeek(EndOfPeriod + (86400 * 7 * Direction));
		
	ElsIf PeriodName = "Month" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfMonth(AddMonth(EndOfPeriod, (1 * Direction)));
		ValueEndPeriod	= EndOfMonth(AddMonth(EndOfPeriod, (1 * Direction)));
		
	ElsIf PeriodName = "Quarter" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfQuarter(AddMonth(EndOfPeriod, (3 * Direction)));
		ValueEndPeriod	= EndOfQuarter(AddMonth(EndOfPeriod, (3 * Direction)));
		
	ElsIf PeriodName = "Year" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfYear(AddMonth(EndOfPeriod, (12 * Direction)));
		ValueEndPeriod	= EndOfYear(AddMonth(EndOfPeriod, (12 * Direction)));
		
	EndIf;
		
	BeginOfPeriod = BeginOfPeriodValue;
	EndOfPeriod = ValueEndPeriod;
	
EndProcedure // SetPeriod()

// Procedure generates and updates period label on the form
//
&AtClient
Procedure SetPeriodLabel()
	
	//If no button is enabled - Arbitrary period
	If RadioButton = "" Then
		
		PeriodPresentation = "Arbitrary period";
		
	ElsIf Month(BeginOfPeriod) = Month(EndOfPeriod) Then
		
		DayOfScheduleBegin = Format(BeginOfPeriod, "DF=dd");
		DayOfScheduleEnd = Format(EndOfPeriod, "DF=dd");
		MonthOfScheduleEnd = Format(EndOfPeriod, "DF=MMM");
		YearOfSchedule = Format(Year(EndOfPeriod), "NG=0");
		
		PeriodPresentation = DayOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
		
	Else
		
		DayOfScheduleBegin = Format(BeginOfPeriod, "DF=dd");
		MonthOfScheduleBegin = Format(BeginOfPeriod, "DF=MMM");
		DayOfScheduleEnd = Format(EndOfPeriod, "DF=dd");
		MonthOfScheduleEnd = Format(EndOfPeriod, "DF=MMM");
		
		If Year(BeginOfPeriod) = Year(EndOfPeriod) Then
			YearOfSchedule = Format(Year(EndOfPeriod), "NG=0");
			PeriodPresentation = DayOfScheduleBegin + " " + MonthOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
			
		Else
			YearOfScheduleBegin = Format(Year(BeginOfPeriod), "NG=0");
			YearOfScheduleEnd = Format(Year(EndOfPeriod), "NG=0");
			PeriodPresentation = DayOfScheduleBegin + " " + MonthOfScheduleBegin + " " + YearOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + " " + YearOfScheduleEnd;
			
		EndIf;
		
	EndIf;

EndProcedure // SetPeriodLabel()

&AtClient
Procedure RadioButtonOnChange(Item)
	
	SetPeriod(RadioButton, 0);
	SetPeriodLabel();
	
EndProcedure
