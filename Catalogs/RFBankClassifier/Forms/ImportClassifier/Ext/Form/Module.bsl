&AtClient
Var IdleHandlerParameters;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenFromList") Then
		// Open by navigation reference.
		If WorkWithBanks.ClassifierIsActual() Then
			NotifyClassifierIsActual = True;
			Return;
		EndIf;
	EndIf;
	
	If CommonUseClientServer.ThisIsWebClient() Then
		AutoSaveDataInSettings = AutoSaveFormDataInSettings.DontUse;
		Items.ImportingOption.Enabled = False;
		Items.PathToITSDisk.Enabled = False;
		Items.FormPages.CurrentPage = Items.ImportingFromRBKSite;
	Else
		Items.FormPages.CurrentPage = Items.PageSelectSource;
	EndIf;
	
	VerifyAccessRights("Update", Metadata.Catalogs.RFBankClassifier);
	ImportingOption = "RBC";
	
	SetChangesInInterface();
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	SetChangesInInterface();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If NotifyClassifierIsActual Then
		WorkWithBanksClient.NotifyClassifierIsActual();
		Cancel = True;
		Return;
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ImportingOptionOnChange(Item)
	SetChangesInInterface();
EndProcedure

&AtClient
Procedure PathToITSDiskStartChoice(Item, ChoiceData, StandardProcessing)
	
	ClearMessages();
	
	SelectDirectoryDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	SelectDirectoryDialog.Title = NStr("en = 'Specify path to ITS disk'");
	SelectDirectoryDialog.Directory   = PathToITSDisk;
	
	If Not SelectDirectoryDialog.Choose() Then
		Return;
	EndIf;
	
	PathToITSDisk = CommonUseClientServer.AddFinalPathSeparator(SelectDirectoryDialog.Directory);
	
	DataFile = New File(PathToITSDisk + "Database\Garant\MorphDB\Morph.dlc");
	If Not DataFile.Exist() Then
		CommonUseClientServer.MessageToUser(
			NStr("en ='Classifier data was not found in the specified directory. It is necessary to specify the path to the disk 1C:ITS on which there is the base ""Garant. Taxes, accounting, entrepreneurship.""'"),
			,
			"PathToITSDisk");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GoToNext(Command)
	
	If Items.FormPages.CurrentPage = Items.ResultPage Then
		Close();
	Else
		ClearMessages();
		
		If ImportingOption = "ITS" AND Not ValueIsFilled(PathToITSDisk) AND CommonUseClientServer.IsLinuxClient() Then
			// Under Linux - search of drive letters is impossible.
			CommonUseClientServer.MessageToUser(
				NStr("en = 'When working under Linux OS it is necessary to distinctly specify the path to the disk'"),
				,
				"PathToITSDisk");
			Return;
		EndIf;
		Items.FormPages.CurrentPage = Items.ImportingInProgress;
		SetChangesInInterface();
		AttachIdleHandler("ImportClassifier", 0.1, True);
	EndIf;

EndProcedure

&AtClient
Procedure Back(Command)
	CurrentPage = Items.FormPages.CurrentPage;
	
	If CurrentPage = Items.ResultPage Then
		#If WebClient Then
		Items.FormPages.CurrentPage = Items.ImportingFromRBKSite;
		#Else
		Items.FormPages.CurrentPage = Items.PageSelectSource;
		#EndIf
	EndIf;
	
	SetChangesInInterface();

EndProcedure

&AtClient
Procedure Cancel(Command)
	If ValueIsFilled(JobID) Then
		CompleteBackgroundTasks(JobID);
	EndIf;
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure ImportClassifier()
	// Imports bank classifier from ITS drive or from RBC site.
	
	ClassifierImportParameters = New Map;
	// (Number) Quantity of new classifier records:
	ClassifierImportParameters.Insert("Exported", 0);
	// (Number) Quantity of updated classifier records:
	ClassifierImportParameters.Insert("Updated", 0);
	// (String) Message text about import results:
	ClassifierImportParameters.Insert("MessageText", "");
	// (Boolean) Flag of successfull classifier data import complete:
	ClassifierImportParameters.Insert("ImportCompleted", False);
	
	If ImportingOption = "ITS" Then
		GetBICRFDataDiscITS(ClassifierImportParameters);
		StorageAddress = PutToTempStorage(Undefined, UUID);
		PutToTempStorage(ClassifierImportParameters, StorageAddress);
		Result = New Structure("TaskDone, StorageAddress", True, StorageAddress);
	ElsIf ImportingOption = "RBC" Then
		Result = GetRBCDataFromServer(ClassifierImportParameters);
	EndIf;
	
	StorageAddress = Result.StorageAddress;
	If Not Result.JobCompleted Then
		JobID = Result.JobID;
		
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	Else
		ImportResult();
	EndIf;
 EndProcedure 

&AtClient
Procedure ImportResult()
	// Displays the import attempt result of Russian Federation bank
	// classifier in the events log monitor and in import form.
	
	If ImportingOption = "ITS" Then
		Source = NStr("en ='ITS disk'");
	Else
		Source = NStr("en ='RBK site'");
	EndIf;
	
	ClassifierImportParameters = GetFromTempStorage(StorageAddress);
	
	EventName = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en ='Banks classifier import. %1.'"), Source);
	
	If ClassifierImportParameters["ImportCompleted"] Then
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventName,, 
			ClassifierImportParameters["MessageText"],, True);
		WorkWithBanksClient.NotifyClassifierUpdatedSuccessfully();
	Else
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventName, 
			"Error", ClassifierImportParameters["MessageText"],, True);
	EndIf;
	Items.ExplanationText.Title = ClassifierImportParameters["MessageText"];
	
	Items.FormPages.CurrentPage = Items.ResultPage;
	SetChangesInInterface();
	
	If (ClassifierImportParameters["Updated"] > 0) Or (ClassifierImportParameters["Exported"] > 0) Then
		NotifyChanged(Type("CatalogRef.RFBankClassifier"));
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()
	JobCompleted = Undefined;
	Try
		JobCompleted = JobCompleted(JobID);
	Except
		EventLogMonitorClient.AddMessageForEventLogMonitor(NStr("en = 'Import banks classifier'", CommonUseClientServer.MainLanguageCode()),
			"Error", DetailErrorDescription(ErrorInfo()), , True);
			
		Items.ExplanationText.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Bank classifier import is aborted
				|by the reason of: %1
				|Details see in events log monitor.'"),
			BriefErrorDescription(ErrorInfo()));
			
		Items.FormPages.CurrentPage = Items.ResultPage;
		SetChangesInInterface();
		Return;
	EndTry;
		
	If JobCompleted Then 
		ImportResult();
	Else
		LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler(
			"Attachable_CheckJobExecution", 
			IdleHandlerParameters.CurrentInterval, 
			True);
	EndIf;

EndProcedure

&AtClient
Procedure GetBICRFDataDiscITS(ClassifierImportParameters) 
	// Receives, sorts, writes classifier data BIC RF from ITS drive.
	
	ITSFilesImportingParameters = New Map;
	// (String) Path to ITS disc:
	ITSFilesImportingParameters.Insert("PathToITSDisk", "");
	// (String) Address in temporary storage according to which the classifier data file is placed:
	ITSFilesImportingParameters.Insert("ITSDataBinaryDataAddress", "");
	// (String) Address in temporary storage according to which the prepare data processor file is placed:
	ITSFilesImportingParameters.Insert("ITSPreparingBinaryDataAddress", "");
	// (String) Error text:
	ITSFilesImportingParameters.Insert("MessageText", ClassifierImportParameters["MessageText"]);
	// Other parameters - see variable description RBKFileImportParameters in ImportClassifier():
	ITSFilesImportingParameters.Insert("Exported", ClassifierImportParameters["Exported"]);
	ITSFilesImportingParameters.Insert("Updated", ClassifierImportParameters["Updated"]);
	
	GetDataBIKITSdisc(ITSFilesImportingParameters);
	
	If Not IsBlankString(ITSFilesImportingParameters["MessageText"]) Then
		ClassifierImportParameters.Insert("MessageText", ITSFilesImportingParameters["MessageText"]);
		Return;
	EndIf;
	
	GetDiskSorterITS(ITSFilesImportingParameters);
	
	If Not IsBlankString(ITSFilesImportingParameters["MessageText"]) Then
		ClassifierImportParameters.Insert("MessageText", ITSFilesImportingParameters["MessageText"]);
		Return;
	EndIf;
	
	DataExportDiscITSOnServer(ITSFilesImportingParameters);
	
	ClassifierImportParameters.Insert("Exported", ITSFilesImportingParameters["Exported"]);
	ClassifierImportParameters.Insert("Updated", ITSFilesImportingParameters["Updated"]);
	ClassifierImportParameters.Insert("MessageText", ITSFilesImportingParameters["MessageText"]);
	ClassifierImportParameters.Insert("ImportCompleted", True);
	
EndProcedure

&AtClient
Procedure GetDataBIKITSdisc(ITSFilesImportingParameters)
	// Receives classifier data BIC RF from ITS drive.
	// 
// Parameters:
	//   ITSFilesImportingParameters - see description of the same name variable in GetBICRFDataDiscITS().
	
	DataFile = Undefined;
	FileFound = False;
	
	Result = New Structure;
	If ValueIsFilled(PathToITSDisk) Then
		// Path to the drive is specified clearly.
		PathToITSDisk = CommonUseClientServer.AddFinalPathSeparator(PathToITSDisk);
		DataFile = New File(PathToITSDisk + "Database\Garant\MorphDB\Morph.dlc");
		If DataFile.Exist() Then
			ITSFilesImportingParameters.Insert("PathToITSDisk", PathToITSDisk);
			FileFound = True;
		Else
			SupportData = "";
		EndIf;
	Else
		// Under Linux - checking is placed previously in Next().
		// Under Windows - search of drive letters from D to Z.
		For IndexOf = 68 To 90 Do
			FoundPathToITSDisk = Char(IndexOf) + ":\";
			DataFile = New File(FoundPathToITSDisk + "Database\Garant\MorphDB\Morph.dlc");
			If DataFile.Exist() Then
				ITSFilesImportingParameters.Insert("PathToITSDisk", FoundPathToITSDisk);
				FileFound = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If FileFound Then
		ITSDataBinaryDataAddress = PutToTempStorage(New BinaryData(DataFile.FullName));
		ITSFilesImportingParameters.Insert("ITSDataBinaryDataAddress", ITSDataBinaryDataAddress);
		DataFile = Undefined;
	Else
		MessageText = NStr("en ='On the drive 1C:ITS BIC RF classifier data was not found. 
		|To install, you need 1C:ITS disk containing the database ""Garant. Taxes, accounting, entrepreneurship.""'");
		ITSFilesImportingParameters.Insert("MessageText", MessageText);
	EndIf;
	
	ITSFilesImportingParameters.Insert("MessageText", MessageText);
	
EndProcedure

&AtClient
Procedure GetDiskSorterITS(ITSFilesImportingParameters)
	// Receives classifier sorting data processor BIC RF from ITS drive.
	// 
// Parameters:
	//   ITSFilesImportingParameters - see description of the same name variable in GetBICRFDataDiscITS().
	
	FileDataProcessors = New File(ITSFilesImportingParameters["PathToITSDisk"] + "1CITS\EXE\EXTDB\BIKr5v82_MA.epf");
	
	If FileDataProcessors.Exist() Then
		BinaryDataAddress = PutToTempStorage(New BinaryData(FileDataProcessors.FullName));
		ITSFilesImportingParameters.Insert("ITSPreparingBinaryDataAddress", BinaryDataAddress);
	Else
		ITSFilesImportingParameters.Insert("MessageText", NStr("en ='File for the data preparation processing of the BIC RF classifier has not been found on the ITS disk.'"));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServerNoContext
Function JobCompleted(JobID)
	Return LongActions.JobCompleted(JobID);
EndFunction

&AtServer
Procedure SetChangesInInterface()
	// Depending on the current page it sets the accessibility of certain fields for the user.
	
	Items.PathToITSDisk.Enabled = (ImportingOption = "ITS");
	
	If Items.FormPages.CurrentPage = Items.PageSelectSource
		Or Items.FormPages.CurrentPage = Items.ImportingFromRBKSite Then
		Items.FormButtonBack.Visible  = False;
		Items.FormNextButton.Title = NStr("en ='Import'");
		Items.FormCancelButton.Enabled = True;
		Items.FormNextButton.Enabled  = True;
	ElsIf Items.FormPages.CurrentPage = Items.ImportingInProgress Then
		Items.FormButtonBack.Visible = False;
		Items.FormNextButton.Enabled  = False;
		Items.FormCancelButton.Enabled = True;
	Else
		Items.FormButtonBack.Visible = True;
		Items.FormNextButton.Title = NStr("en ='Close'");
		Items.FormCancelButton.Enabled = False;
		Items.FormNextButton.Enabled  = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure CompleteBackgroundTasks(JobID)
	BackgroundJob = BackgroundJobs.FindByUUID(JobID);
	If BackgroundJob <> Undefined Then
		BackgroundJob.Cancel();
	EndIf;
EndProcedure

&AtServer
Procedure DataExportDiscITSOnServer(ITSFilesImportingParameters)
	// Imports data from ITS drive in the bank classifier.
	// 
// Parameters:
//    ITSFilesImportingParameters - see variable description ClassifierImportParameters
	//                                in GetBICRFDataDiscITS().
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Raise TextImportingIsProhibited();
	EndIf;
	
	WorkWithBanks.ImportDataITSdisc(ITSFilesImportingParameters);
	
EndProcedure

&AtServer
Function GetRBCDataFromServer(RBKFilesImportingParameters)
	// Imports data from ITS drive to the bank classifier.
	//
// Parameters:
	//   RBKFilesImportingParameters - see description of the same name variable in ImportClassifier().
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Raise TextImportingIsProhibited();
	EndIf;
	
	JobDescription = NStr("en = 'Import bank classifier'");
	
	Result = LongActions.ExecuteInBackground(
		UUID,
		"WorkWithBanks.GetRBCData", 
		RBKFilesImportingParameters, 
		JobDescription);
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function TextImportingIsProhibited()
	Return NStr("en = 'Import of the banks classifier in the separated mode is prohibited'");
EndFunction

#EndRegion
