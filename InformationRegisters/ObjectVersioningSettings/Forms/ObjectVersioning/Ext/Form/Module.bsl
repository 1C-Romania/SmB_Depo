

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FillObjectTypesInValueTree();
	FillChoiceLists();
	
	Items.Clear.Visible = False;
	Items.Schedule.Title = CurrentSchedule();
	AutomaticallyDeleteOutdatedVersions = AutomaticClearingIsEnable();
	Items.Schedule.Enabled = AutomaticallyDeleteOutdatedVersions;
	Items.ConfigureSchedule.Enabled = AutomaticallyDeleteOutdatedVersions;
	Items.InformationAboutLegacyVersions.Title = StatusTextCalculation();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateInformationAboutOutdatedVersions();
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersMetadataObjectTree

&AtClient
Procedure MetadataObjectTreeBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData.GetParent() = Undefined Then
		Cancel = True;
	EndIf;
	
	If Item.CurrentItem = Items.VersioningVariant Then
		FillChoiceList(Items.MetadataObjectTree.CurrentItem);
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingsOnChange(Item)
	CurrentData = Items.MetadataObjectTree.CurrentData;
	WriteCurrentSettingsByObject(CurrentData.ObjectType, CurrentData.VersioningVariant, CurrentData.VersionsStorageTerm);
	UpdateInformationAboutOutdatedVersions();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SetVersioningVariantDoNotVersion(Command)
	
	SetVersioningVariantForSelectedRows(
		PredefinedValue("Enum.ObjectVersioningOptions.DoNotVersion"));	
	
EndProcedure

&AtClient
Procedure SetVersioningModeOnWrite(Command)
	
	SetVersioningVariantForSelectedRows(
		PredefinedValue("Enum.ObjectVersioningOptions.VersionOnWrite"));	
	
EndProcedure

&AtClient
Procedure SetVersioningVariantOnPosting(Command)
	
	If SelectNoPostingDocumentsType() Then
		ShowMessageBox(, NStr("en='The versioning mode ""Versioning on record"" is enabled for the documents which can not be posted.';ru='Документам, которые не могут быть проведены, установлен режим версионирования ""Версионировать при записи"".'"));
	EndIf;
	
	SetVersioningVariantForSelectedRows(
		PredefinedValue("Enum.ObjectVersioningOptions.VersionOnPosting"));	
	
EndProcedure

&AtClient
Procedure SetSettingsDefault(Command)
	
	SetVersioningVariantForSelectedRows(Undefined);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	FillObjectTypesInValueTree();
	UpdateInformationAboutOutdatedVersions();
	For Each Item IN MetadataObjectTree.GetItems() Do
		Items.MetadataObjectTree.Expand(Item.GetID(), True);
	EndDo;
EndProcedure

&AtClient
Procedure Clear(Command)
	BreakBackgroundJob();
	RunScheduledJob();
	StartUpdateInformationAboutOutdatedVersions();
	AttachIdleHandler("CheckBackgroundJobExecution", 2, True);
EndProcedure

&AtClient
Procedure InLastWeek(Command)
	SetVersionStorageTermForSelectedObjects(
		PredefinedValue("Enum.VersionStorageTerms.InLastWeek"));
	UpdateInformationAboutOutdatedVersions();
EndProcedure

&AtClient
Procedure InLastMonth(Command)
	SetVersionStorageTermForSelectedObjects(
		PredefinedValue("Enum.VersionStorageTerms.InLastMonth"));
	UpdateInformationAboutOutdatedVersions();
EndProcedure

&AtClient
Procedure ForLastThreeMonths(Command)
	SetVersionStorageTermForSelectedObjects(
		PredefinedValue("Enum.VersionStorageTerms.ForLastThreeMonths"));
	UpdateInformationAboutOutdatedVersions();
EndProcedure

&AtClient
Procedure ForLastSixMonths(Command)
	SetVersionStorageTermForSelectedObjects(
		PredefinedValue("Enum.VersionStorageTerms.ForLastSixMonths"));
	UpdateInformationAboutOutdatedVersions();
EndProcedure

&AtClient
Procedure ForLastYear(Command)
	SetVersionStorageTermForSelectedObjects(
		PredefinedValue("Enum.VersionStorageTerms.ForLastYear"));
	UpdateInformationAboutOutdatedVersions();
EndProcedure

&AtClient
Procedure Indefinitely(Command)
	SetVersionStorageTermForSelectedObjects(
		PredefinedValue("Enum.VersionStorageTerms.Indefinitely"));
	UpdateInformationAboutOutdatedVersions();
EndProcedure

&AtClient
Procedure VersionOnStart(Command)
	SetVersioningVariantForSelectedRows(
		PredefinedValue("Enum.ObjectVersioningOptions.VersionOnStart"));
EndProcedure

&AtClient
Procedure ConfigureSchedule(Command)
	ScheduleDialog = New ScheduledJobDialog(CurrentSchedule());
	NotifyDescription = New NotifyDescription("ConfigureScheduleEnd", ThisObject);
	ScheduleDialog.Show(NOTifyDescription);
EndProcedure

&AtClient
Procedure CountAndVolumeStoredObjectsVersions(Command)
	OpenForm("Report.ObjectsVersionsAnalysis.ObjectForm");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure FillChoiceList(Item)
	
	TreeRow = Items.MetadataObjectTree.CurrentData;
	
	Item.ChoiceList.Clear();
	
	If TreeRow.ClassObject = "ClassDocuments" AND TreeRow.IsPosting Then
		ChoiceList = ChoiceListDocuments;
	ElsIf TreeRow.ClassObject = "ClassBusinessProcesses" Then
		ChoiceList = BusinessProcessesChoiceList;
	Else
		ChoiceList = ChoiceListCatalogs;
	EndIf;
	
	For Each ItemOfList IN ChoiceList Do
		Item.ChoiceList.Add(ItemOfList.Value);
	EndDo;
	
EndProcedure

&AtServer
Procedure FillObjectTypesInValueTree()
	
	VersioningSettings = CurrentVersioningSettings();
	
	CMTree = FormAttributeToValue("MetadataObjectTree");
	CMTree.Rows.Clear();
	
	// Type of command parameter ChangeHistory contains object content for which versioning is applied.
	TypeArray = Metadata.CommonCommands.ChangesHistory.CommandParameterType.Types();
	IsCatalogs = False;
	AreDocuments = False;
	AllCatalogs = Catalogs.AllRefsType();
	AllDocuments = Documents.AllRefsType();
	CatalogsNod = Undefined;
	DocumentsNode = Undefined;
	NodeBusinessProcesses = Undefined;
	
	For Each Type IN TypeArray Do
		If AllCatalogs.ContainsType(Type) Then
			If CatalogsNod = UNDEFINED Then
				CatalogsNod = CMTree.Rows.Add();
				CatalogsNod.SynonymNameObject = NStr("en='Catalogs';ru='Справочники'");
				CatalogsNod.ClassObject = "01ClassReferencesRoot";
				CatalogsNod.PictureCode = 2;
			EndIf;
			NewTableRow = CatalogsNod.Rows.Add();
			NewTableRow.PictureCode = 19;
			NewTableRow.ClassObject = "ClassCatalogs";
		ElsIf AllDocuments.ContainsType(Type) Then
			If DocumentsNode = UNDEFINED Then
				DocumentsNode = CMTree.Rows.Add();
				DocumentsNode.SynonymNameObject = NStr("en='Documents';ru='Документы'");
				DocumentsNode.ClassObject = "02ClassDocumentsRoot";
				DocumentsNode.PictureCode = 3;
			EndIf;
			NewTableRow = DocumentsNode.Rows.Add();
			NewTableRow.PictureCode = 20;
			NewTableRow.ClassObject = "ClassDocuments";
		ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
			If NodeBusinessProcesses = Undefined Then
				NodeBusinessProcesses = CMTree.Rows.Add();
				NodeBusinessProcesses.SynonymNameObject = NStr("en='Business-processes';ru='Деловые процессы'");
				NodeBusinessProcesses.ClassObject = "03BusinessProcessesRoot";
				NodeBusinessProcesses.ObjectType = "BusinessProcesses";
			EndIf;
			NewTableRow = NodeBusinessProcesses.Rows.Add();
			NewTableRow.ClassObject = "ClassBusinessProcesses";
		EndIf;
		ObjectMetadata = Metadata.FindByType(Type);
		NewTableRow.ObjectType = CommonUse.MetadataObjectID(Type);
		NewTableRow.SynonymNameObject = ObjectMetadata.Synonym;
		
		FoundSettings = VersioningSettings.FindRows(New Structure("ObjectType", NewTableRow.ObjectType));
		If FoundSettings.Count() > 0 Then
			NewTableRow.VersioningVariant = FoundSettings[0].VersioningVariant;
			NewTableRow.VersionsStorageTerm = FoundSettings[0].VersionsStorageTerm;
			If Not ValueIsFilled(FoundSettings[0].VersionsStorageTerm) Then
				NewTableRow.VersionsStorageTerm = Enums.VersionStorageTerms.Indefinitely;
			EndIf;
		Else
			NewTableRow.VersioningVariant = Enums.ObjectVersioningOptions.DoNotVersion;
			NewTableRow.VersionsStorageTerm = Enums.VersionStorageTerms.Indefinitely;
		EndIf;
		
		If NewTableRow.ClassObject = "ClassDocuments" Then
			NewTableRow.IsPosting = ? (ObjectMetadata.Posting = Metadata.ObjectProperties.Posting.Allow, True, False);
		EndIf;
	EndDo;
	CMTree.Rows.Sort("ClassObject");
	For Each UpperLevelNod IN CMTree.Rows Do
		UpperLevelNod.Rows.Sort("SynonymNameObject");
	EndDo;
	ValueToFormAttribute(CMTree, "MetadataObjectTree");
	
EndProcedure

&AtClient
Function SelectNoPostingDocumentsType()
	
	For Each RowID IN Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		If TreeItem.ClassObject = "ClassDocuments" AND Not TreeItem.IsPosting Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Procedure SetVersioningVariantForSelectedRows(Val VersioningVariant)
	
	For Each RowID IN Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		If TreeItem.GetParent() = Undefined Then 
			For Each TreeChildItem IN TreeItem.GetItems() Do
				SetVersioningVariantForTreeItem(TreeChildItem, VersioningVariant);
			EndDo;
		Else
			SetVersioningVariantForTreeItem(TreeItem, VersioningVariant);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetVersioningVariantForTreeItem(TreeItem, Val VersioningVariant)
	
	If VersioningVariant = Undefined Then
		If TreeItem.ClassObject = "ClassDocuments" Then
			VersioningVariant = Enums.ObjectVersioningOptions.VersionOnPosting;
		ElsIf TreeItem.GetParent().ObjectType = "BusinessProcesses" Then
			VersioningVariant = Enums.ObjectVersioningOptions.VersionOnStart;
		Else
			VersioningVariant = Enums.ObjectVersioningOptions.DoNotVersion;
		EndIf;
	EndIf;
	
	If VersioningVariant = Enums.ObjectVersioningOptions.VersionOnPosting
		AND Not TreeItem.IsPosting 
		Or VersioningVariant = Enums.ObjectVersioningOptions.VersionOnStart
		AND TreeItem.ClassObject <> "ClassBusinessProcesses" Then
			VersioningVariant = Enums.ObjectVersioningOptions.VersionOnWrite;
	EndIf;
	
	TreeItem.VersioningVariant = VersioningVariant;
	
	WriteCurrentSettingsByObject(TreeItem.ObjectType, VersioningVariant, TreeItem.VersionsStorageTerm);
	
EndProcedure

&AtServer
Procedure SetVersionStorageTermForSelectedObjects(VersionsStorageTerm)
	
	For Each RowID IN Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		If TreeItem.GetParent() = Undefined Then
			For Each TreeChildItem IN TreeItem.GetItems() Do
				SetVersionStorageTermForSelectedObject(TreeChildItem, VersionsStorageTerm);
			EndDo;
		Else
			SetVersionStorageTermForSelectedObject(TreeItem, VersionsStorageTerm);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetVersionStorageTermForSelectedObject(SelectedObject, VersionsStorageTerm)
	
	SelectedObject.VersionsStorageTerm = VersionsStorageTerm;
	WriteCurrentSettingsByObject(SelectedObject.ObjectType, SelectedObject.VersioningVariant, VersionsStorageTerm);
	
EndProcedure

&AtServer
Procedure WriteCurrentSettingsByObject(ObjectType, VersioningVariant, VersionsStorageTerm)
	ObjectVersioning.WriteVersioningSettingByObject(ObjectType, VersioningVariant, VersionsStorageTerm);
EndProcedure

&AtServer
Function CurrentVersioningSettings()
	SetPrivilegedMode(True);
	QueryText =
	"SELECT
	|	ObjectVersioningSettings.ObjectType AS ObjectType,
	|	ObjectVersioningSettings.Variant AS VersioningVariant,
	|	ObjectVersioningSettings.VersionsStorageTerm AS VersionsStorageTerm
	|FROM
	|	InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings";
	Query = New Query(QueryText);
	Return Query.Execute().Unload();
EndFunction

&AtClient
Procedure ConfigureScheduleEnd(Schedule, AdditionalParameters) Export
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	SetJobSchedule(Schedule);
	Items.Schedule.Title = Schedule;
	
EndProcedure

&AtServer
Procedure SetJobSchedule(Schedule);
	
	If CommonUseReUse.DataSeparationEnabled() Then
		DataArea = CommonUse.SessionSeparatorValue();
		MethodName = Metadata.ScheduledJobs.ClearObsoleteObjectsVersions.MethodName;
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName", MethodName);
		JobParameters.Insert("DataArea", DataArea);
		
		If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleJobQueue = CommonUse.CommonModule("JobQueue");
			JobList = ModuleJobQueue.GetJobs(JobParameters);
			If JobList.Count() = 0 Then
				JobParameters.Insert("Schedule", Schedule);
				ModuleJobQueue.AddJob(JobParameters);
			Else
				JobParameters = New Structure("Schedule", Schedule);
				For Each Task IN JobList Do
					ModuleJobQueue.ChangeTask(Task.ID, JobParameters);
				EndDo;
			EndIf;
		EndIf;
	Else
		ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.ClearObsoleteObjectsVersions);
		ScheduledJob.Schedule = Schedule;
		ScheduledJob.Write();
	EndIf;
	
EndProcedure

&AtServer
Function CurrentSchedule()
	If CommonUseReUse.DataSeparationEnabled() Then
		DataArea = CommonUse.SessionSeparatorValue();
		MethodName = Metadata.ScheduledJobs.ClearObsoleteObjectsVersions.MethodName;
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName", MethodName);
		JobParameters.Insert("DataArea", DataArea);
		
		If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleJobQueue = CommonUse.CommonModule("JobQueue");
		
			JobList = ModuleJobQueue.GetJobs(JobParameters);
			For Each Task IN JobList Do
				Return Task.Schedule;
			EndDo;
		
			Return New JobSchedule;
		EndIf;
	Else
		Return ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.ClearObsoleteObjectsVersions).Schedule;
	EndIf;
EndFunction

&AtClient
Procedure AutomaticallyDeleteOutdatedVersionsOnChange(Item)
	EnableDisableScheduledJob(AutomaticallyDeleteOutdatedVersions);
	Items.Schedule.Enabled = AutomaticallyDeleteOutdatedVersions;
	Items.ConfigureSchedule.Enabled = AutomaticallyDeleteOutdatedVersions;
EndProcedure

&AtServer
Procedure EnableDisableScheduledJob(Use)
	If CommonUseReUse.DataSeparationEnabled() Then
		DataArea = CommonUse.SessionSeparatorValue();
		MethodName = Metadata.ScheduledJobs.ClearObsoleteObjectsVersions.MethodName;
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName", MethodName);
		JobParameters.Insert("DataArea", DataArea);
		
		If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleJobQueue = CommonUse.CommonModule("JobQueue");
			JobList = ModuleJobQueue.GetJobs(JobParameters);
			If JobList.Count() = 0 Then
				JobParameters.Insert("Use", Use);
				ModuleJobQueue.AddJob(JobParameters);
			Else
				JobParameters = New Structure("Use", Use);
				For Each Task IN JobList Do
					ModuleJobQueue.ChangeTask(Task.ID, JobParameters);
				EndDo;
			EndIf;
		EndIf;
	Else
		ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.ClearObsoleteObjectsVersions);
		ScheduledJob.Use = Not ScheduledJob.Use;
		ScheduledJob.Write();
	EndIf;
EndProcedure

&AtClient
Procedure CheckBackgroundJobExecution()
	If Not JobCompleted(BackgroundJobID) Then
		AttachIdleHandler("CheckBackgroundJobExecution", 5, True);
	Else
		BackgroundJobID = "";
		If CurrentBackgroundJob = "Calculation" Then
			DisplayInformationAboutOutdatedVersions();
			Return;
		EndIf;
		CurrentBackgroundJob = "";
		UpdateInformationAboutOutdatedVersions();
	EndIf;
EndProcedure

&AtServerNoContext
Function JobCompleted(BackgroundJobID)
	Return LongActions.JobCompleted(BackgroundJobID);
EndFunction

&AtServerNoContext
Procedure CancelJobExecution(BackgroundJobID)
	LongActions.CancelJobExecution(BackgroundJobID);
EndProcedure

&AtServer
Procedure RunScheduledJob()
	
	ScheduledJobMetadata = Metadata.ScheduledJobs.ClearObsoleteObjectsVersions;
	
	Filter = New Structure;
	MethodName = ScheduledJobMetadata.MethodName;
	Filter.Insert("MethodName", MethodName);
	
	Filter.Insert("State", BackgroundJobState.Active);
	BackgroundJobsCleanup = BackgroundJobs.GetBackgroundJobs(Filter);
	If BackgroundJobsCleanup.Count() > 0 Then
		BackgroundJobID = BackgroundJobsCleanup[0].UUID;
	Else
		BackgroundJobDescription = StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='Launch manually: %1';ru='Запуск вручную: %1'"), ScheduledJobMetadata.Synonym);
		BackgroundJob = BackgroundJobs.Execute(ScheduledJobMetadata.MethodName, , , BackgroundJobDescription);
		BackgroundJobID = BackgroundJob.UUID;
	EndIf;
	
	CurrentBackgroundJob = "Clearing";
	
EndProcedure

&AtClient
Procedure UpdateInformationAboutOutdatedVersions()
	DetachIdleHandler("StartUpdateInformationAboutOutdatedVersions");
	If CurrentBackgroundJob = "Calculation" AND ValueIsFilled(BackgroundJobID) Then
		BreakBackgroundJob();
	EndIf;
	AttachIdleHandler("StartUpdateInformationAboutOutdatedVersions", 2, True);
EndProcedure

&AtClient
Procedure BreakBackgroundJob()
	CancelJobExecution(BackgroundJobID);
	DetachIdleHandler("CheckBackgroundJobExecution");
	CurrentBackgroundJob = "";
	BackgroundJobID = "";
EndProcedure

&AtClient
Procedure StartUpdateInformationAboutOutdatedVersions()
	
	Items.Clear.Visible = CurrentBackgroundJob <> "Clearing";
	If ValueIsFilled(BackgroundJobID) Then
		If CurrentBackgroundJob = "Calculation" Then
			Items.InformationAboutLegacyVersions.Title = StatusTextCalculation();
		Else
			Items.InformationAboutLegacyVersions.Title = StatusTextClearing();
		EndIf;
		Return;
	EndIf;
	
	If RunSearchOutdatedVersions() Then
		DisplayInformationAboutOutdatedVersions();
	Else
		StartUpdateInformationAboutOutdatedVersions();
		AttachIdleHandler("CheckBackgroundJobExecution", 2, True);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function StatusTextCalculation()
	Return NStr("en='Search outdated versions...';ru='Поиск устаревших версий...'");
EndFunction

&AtClientAtServerNoContext
Function StatusTextClearing()
	Return NStr("en='Outdated versions are being cleared...';ru='Выполняется очистка устаревших версий...'");
EndFunction

&AtServer
Function RunSearchOutdatedVersions()
	ExecutionResult = LongActions.ExecuteInBackground(UUID,
		"ObjectVersioning.InformationAboutOutdatedVersionsInBackground", New Structure);
	ResultAddress = ExecutionResult.StorageAddress;
	If Not ExecutionResult.JobCompleted Then
		CurrentBackgroundJob = "Calculation";
		BackgroundJobID = ExecutionResult.JobID;
	EndIf;
	Return ExecutionResult.JobCompleted;
EndFunction

&AtClient
Procedure DisplayInformationAboutOutdatedVersions()
	
	InformationAboutLegacyVersions = GetFromTempStorage(ResultAddress);
	If InformationAboutLegacyVersions = Undefined Then
		Return;
	EndIf;
	
	Items.Clear.Visible = InformationAboutLegacyVersions.DataSize > 0;
	If InformationAboutLegacyVersions.DataSize > 0 Then
		Items.InformationAboutLegacyVersions.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Total outdated versions: %1 (%2)';ru='Всего устаревших версий: %1 (%2)'"),
			InformationAboutLegacyVersions.CountVersions,
			InformationAboutLegacyVersions.DataSizeString);
	Else
		Items.InformationAboutLegacyVersions.Title = NStr("en='Total outdated versions: no';ru='Всего устаревших версий: нет'");
	EndIf;
	
EndProcedure

&AtServer
Procedure FillChoiceLists()
	
	ChoiceListCatalogs = New ValueList;
	ChoiceListCatalogs.Add(Enums.ObjectVersioningOptions.VersionOnWrite);
	ChoiceListCatalogs.Add(Enums.ObjectVersioningOptions.DoNotVersion);
	
	ChoiceListDocuments = New ValueList;
	ChoiceListDocuments.Add(Enums.ObjectVersioningOptions.VersionOnWrite);
	ChoiceListDocuments.Add(Enums.ObjectVersioningOptions.VersionOnPosting);
	ChoiceListDocuments.Add(Enums.ObjectVersioningOptions.DoNotVersion);
	
	BusinessProcessesChoiceList = New ValueList;
	BusinessProcessesChoiceList.Add(Enums.ObjectVersioningOptions.VersionOnWrite);
	BusinessProcessesChoiceList.Add(Enums.ObjectVersioningOptions.VersionOnStart);
	BusinessProcessesChoiceList.Add(Enums.ObjectVersioningOptions.DoNotVersion);
	
EndProcedure

&AtServer
Function AutomaticClearingIsEnable()
	If CommonUseReUse.DataSeparationEnabled() Then
		DataArea = CommonUse.SessionSeparatorValue();
		MethodName = Metadata.ScheduledJobs.ClearObsoleteObjectsVersions.MethodName;
		
		JobParameters = New Structure;
		JobParameters.Insert("MethodName", MethodName);
		JobParameters.Insert("DataArea", DataArea);
		
		If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleJobQueue = CommonUse.CommonModule("JobQueue");
			JobList = ModuleJobQueue.GetJobs(JobParameters);
			For Each Task IN JobList Do
				Return Task.Use;
			EndDo;
		EndIf;
	Else
		Return ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.ClearObsoleteObjectsVersions).Use;
	EndIf;
	
	Return False;
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
