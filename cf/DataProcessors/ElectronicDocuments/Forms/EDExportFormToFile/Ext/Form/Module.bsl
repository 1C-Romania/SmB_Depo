&AtClient
Var IdleHandlerParameters;

&AtClient
Var LongOperationForm;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClient
Procedure ChangeVisibleEnabled()
	
	DumpToEMail = (ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail"));
	Items.PageLetter.Enabled = DumpToEMail OR (Items.Pages.CurrentPage = Items.AccessDenied);
	
EndProcedure

&AtServer
Procedure ChangeVisibleOfEnabledWhenCreatingServer()
	
	Text = NStr("en='Exporting the documents to file';ru='Выгрузка документов в файл'");
	HyperlinkText = NStr("en='Documents are not found.';ru='Документы не найдены.'");
	If DataTable.Count() > 1 Then
		HyperlinkText = NStr("en='Open the electronic documents list (%1)';ru='Открыть список электронных документов (%1)'");
		HyperlinkText = StrReplace(HyperlinkText, "%1", DataTable.Count());
	ElsIf DataTable.Count() = 1 Then
		HyperlinkText = NStr("en='Electronic document: %1';ru='Электронный документ: %1'");
		HyperlinkText = StrReplace(HyperlinkText, "%1", DataTable[0].FileDescription);
	EndIf;
	Items.PreliminaryDocumentReview.Title = HyperlinkText;
	Title = Text;
	
	If Not AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		ExportMethod = "ThroughDirectory";
		Items.Pages.CurrentPage = Items.AccessDenied;
		Items.ExportMethod.Enabled = False;
	EndIf;
	
	If ExportMethod <> Enums.EDExchangeMethods.ThroughEMail Then
		ExportMethod = Enums.EDExchangeMethods.ThroughDirectory;
	ElsIf Not AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		ExportMethod = "ThroughDirectory";
		Items.Pages.CurrentPage = Items.AccessDenied;
		Items.ExportMethod.Enabled = False;
	Else
		ChangeDumpMethod();
	EndIf;
	
EndProcedure

&AtClient
Procedure GetEDToView(DataRow)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("StorageAddress");
	ParametersStructure.Insert("FileOfArchive", True);
	ParametersStructure.Insert("FileDescription");
	ParametersStructure.Insert("EDDirection");
	ParametersStructure.Insert("Counterparty");
	ParametersStructure.Insert("UUID");
	ParametersStructure.Insert("EDOwner");

	FillPropertyValues(ParametersStructure, DataRow);
	EDViewForm = OpenForm("DataProcessor.ElectronicDocuments.Form.EDViewImportForm",
		New Structure("EDStructure", ParametersStructure), ThisObject, ParametersStructure.UUID);
	
EndProcedure

&AtServer
Function GetAccount()
	
	Query = New Query();
	Query.Text =
	"SELECT ALLOWED
	|	EmailAccounts.Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	Not EmailAccounts.DeletionMark
	|	AND EmailAccounts.UseForSending";
	
	Result = Query.Execute().Select();
	If Result.Count() = 1 Then
		Result.Next();
		Return Result.Ref;
	EndIf;
	
	Return Catalogs.EmailAccounts.EmptyRef();

EndFunction

&AtClient
Function DumpED(MessageText)
	
	Cancel = False;
	If Not ValueIsFilled(ExportMethod) Then
		MessageText = NStr("en='It is necessary to specify the export method';ru='Необходимо указать способ выгрузки.'");
		Cancel = True;
	EndIf;
	If ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail")
		AND Not ValueIsFilled(UserAccount) Then
		MessageText = MessageText + ?(ValueIsFilled(MessageText), Chars.LF, "")
			+ NStr("en='Required to specify the account.';ru='Необходимо указать учетную запись.'");
		Cancel = True;
	EndIf;
	If Not Cancel Then
		ParametersStructure = New Structure;
		ParametersStructure.Insert("ExportMethod",  ExportMethod);
		ParametersStructure.Insert("PathToDirectory");
		ParametersStructure.Insert("UserAccount",   UserAccount);
		ParametersStructure.Insert("RecipientAddress", RecipientAddress);
		
		StructuresArray = New Array;
		
		For Each DataRow IN DataTable Do
			ExchangeStructure = New Structure;

			ExchangeStructure.Insert("FileDescription", DataRow.FileDescription);
			ExchangeStructure.Insert("EDDirection",     DataRow.EDDirection);
			ExchangeStructure.Insert("Counterparty",        DataRow.Counterparty);
			ExchangeStructure.Insert("UUID", DataRow.UUID);
			ExchangeStructure.Insert("EDOwner",        DataRow.EDOwner);
			ExchangeStructure.Insert("StorageAddress",    DataRow.StorageAddress);
			
			StructuresArray.Add(ExchangeStructure);
		EndDo;
		
		QuickExchangeExportED(StructuresArray, ParametersStructure);
	EndIf;
	
	Return Cancel;
	
EndFunction

&AtServer
Procedure ChangeDumpMethod()
	
	If ExportMethod = Enums.EDExchangeMethods.ThroughEMail Then
		If ValueIsFilled(Counterparty) AND Not ValueIsFilled(RecipientAddress) Then
			RecipientAddress = ElectronicDocumentsOverridable.CounterpartyEMailAddress(Counterparty);
		EndIf;
		If Not ValueIsFilled(UserAccount) Then
			UserAccount = GetAccount();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure QuickExchangeExportED(ExchangeStructuresArray, ParametersStructure)
	
	Var PathToDirectory;
	
	If ParametersStructure.ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory") Then
		FilesArray = New Array;
		For Each ExchangeStructure IN ExchangeStructuresArray Do
			FileDescription = New TransferableFileDescription(
				ExchangeStructure.FileDescription + ".zip", ExchangeStructure.StorageAddress);
			FilesArray.Add(FileDescription);
		EndDo;
		If FilesArray.Count() Then
			EmptyProcessor = New NotifyDescription("EmptyProcessor", ElectronicDocumentsServiceClient);
			BeginGettingFiles(EmptyProcessor, FilesArray);
		EndIf;
	Else
		FormParameters = New Structure;
		If ExchangeStructuresArray.Count() > 1 Then
			EmailSubject = NStr("en='Electronic document packages';ru='Пакеты электронных документов'");
		Else
			EmailSubject = NStr("en='Package of the electronic document:';ru='Пакет электронного документа:'") + " " + ExchangeStructuresArray[0].FileDescription;
		EndIf;
		FormParameters.Insert("Subject", EmailSubject);
		FormParameters.Insert("UserAccount", ParametersStructure.UserAccount);
		FormParameters.Insert("Whom", ParametersStructure.RecipientAddress);
		Attachments = New ValueList;
		For Each ExchangeStructure IN ExchangeStructuresArray Do
			Attachments.Add(ExchangeStructure.StorageAddress, ExchangeStructure.FileDescription + ".zip");
		EndDo;
		FormParameters.Insert("Attachments", Attachments);
		Form = OpenForm("CommonForm.MessageSending", FormParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportPreparedDataED()
	
	TableED = GetFromTempStorage(StorageAddress);
	
	If Not ValueIsFilled(TableED) Then
		Return;
	EndIf;
	
	For Each String IN TableED Do
		String.StorageAddress = PutToTempStorage(String.BinaryDataPackage, UUID);
	EndDo;
	
	DataTable.Load(TableED);
	
	ChangeVisibleOfEnabledWhenCreatingServer();
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure Attachable_CheckTaskExecutionForED()

	Try
		If JobCompleted(JobID) Then
			ImportPreparedDataED();
			LongActionsClient.CloseLongOperationForm(LongOperationForm);
		Else
			LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler("Attachable_CheckJobExecutionForED",
				IdleHandlerParameters.CurrentInterval, True);
		EndIf;
	Except
		LongActionsClient.CloseLongOperationForm(LongOperationForm);
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;

EndProcedure

&AtClient
Procedure Attachable_RunIdleHandler()
	
	If Not ExecutionResultTasks.JobCompleted Then
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecutionForED", IdleHandlerParameters.CurrentInterval, True);
		LongOperationForm = LongActionsClient.OpenLongOperationForm(ThisObject, JobID);
		
		JobID = ExecutionResultTasks.JobID;
		StorageAddress       = ExecutionResultTasks.StorageAddress;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure ExecuteAction(Command)
	
	ClearMessages();
	
	MessageText = "";
	Cancel = DumpED(MessageText);
	
	If Cancel Then
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		Close();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure ExportMethodOnChange(Item)
	
	ChangeDumpMethod();
	ChangeVisibleEnabled();
	Modified = False;
	
EndProcedure

&AtClient
Procedure Decoration1Click(Item)
	
	If DataTable.Count() > 1 Then
		StructuresArray = New Array;
		For Each DataRow IN DataTable Do
			ParametersStructure = New Structure;
			ParametersStructure.Insert("StorageAddress", DataRow.StorageAddress);
			ParametersStructure.Insert("FileOfArchive", True);
			ParametersStructure.Insert("FileDescription", DataRow.FileDescription);
			ParametersStructure.Insert("EDDirection", DataRow.EDDirection);
			ParametersStructure.Insert("Counterparty", DataRow.Counterparty);
			ParametersStructure.Insert("UUID", DataRow.UUID);
			ParametersStructure.Insert("EDOwner", DataRow.EDOwner);
			
			StructuresArray.Add(ParametersStructure);
		EndDo;
		EDViewForm = OpenForm("DataProcessor.ElectronicDocuments.Form.ExportedDocumentsListForm",
			New Structure("EDStructure", StructuresArray), ThisObject);
	ElsIf DataTable.Count() = 1 Then
		GetEDToView(DataTable[0]);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Import directory.
	StructureDirectory = "";
	If Parameters.Property("StructureDirectory", StructureDirectory) Then
		
		ExchangeSettings = New Structure;
		ExchangeSettings.Insert("EDFProfileSettings",
			New Structure("EDExchangeMethod", Enums.EDExchangeMethods.QuickExchange));
		ExchangeSettings.Insert("Company", StructureDirectory.Company);
		ExchangeSettings.Insert("CompanyID", ElectronicDocumentsOverridable.GetCounterpartyId(
			StructureDirectory.Company, "Company"));
		
		ReturnStructure = ElectronicDocumentsInternal.GenerateProductsAndServicesCatalog(ExchangeSettings, StructureDirectory);
		If Not ValueIsFilled(ReturnStructure) Then
			Cancel = True;
			Return;
		EndIf;
		
		NewRow = DataTable.Add();
		NewRow.FullFileName = ReturnStructure.FullFileName;
		NewRow.FileDescription = ReturnStructure.Description;
		
		If ReturnStructure.Property("FilesArray") AND ReturnStructure.FilesArray.Count() > 0 Then
			AdditionalFilesArchive = ElectronicDocumentsService.AdditionalFilesArchive(ReturnStructure.FilesArray);
			ReturnStructure.Insert("Images", AdditionalFilesArchive);
		EndIf;
		
		BinaryDataPackage = DataProcessors.ElectronicDocuments.GenerateEDTakskomPackageAttachedFile(ReturnStructure);
		NewRow.StorageAddress = PutToTempStorage(BinaryDataPackage, UUID);
		
		ChangeVisibleOfEnabledWhenCreatingServer();
		
	EndIf;
	
	// Import documents.
	RefsToObjectArray = New Array;
	If Parameters.Property("EDStructure", RefsToObjectArray) Then
		If RefsToObjectArray.Count() = 0 Then
			Cancel = True;
			Return;
		EndIf;
		
		FileInfobase = CommonUse.FileInfobase();
		LongActions.CancelJobExecution(JobID);
		JobID = Undefined;
		
		If FileInfobase Then
			StorageAddress = PutToTempStorage(Undefined, UUID);
			DataProcessors.ElectronicDocuments.PrepareDataForFillingDocuments(RefsToObjectArray, StorageAddress);
			ExecutionResultJobs = New Structure("JobCompleted", True);
		Else
			BackgroundJobDescription = NStr("en='Electronic document generation.';ru='Формирование электронного документа.'");
			ExecutionResultJobs = LongActions.ExecuteInBackground(
				UUID,
				"DataProcessors.ElectronicDocuments.PrepareDataForFillingDocuments",
				RefsToObjectArray,
				BackgroundJobDescription);
				
			StorageAddress       = ExecutionResultTasks.StorageAddress;
		EndIf;
		
		If ExecutionResultTasks.JobCompleted Then
			ImportPreparedDataED();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(DataTable) Then
		Cancel = True;
		Return;
	EndIf;
	
	If ValueIsFilled(ExecutionResultTasks) Then
		
		AttachIdleHandler("Attachable_HandlerToRunOut", 1, True);
		
	EndIf;
	
	ChangeVisibleEnabled();
	
EndProcedure



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
