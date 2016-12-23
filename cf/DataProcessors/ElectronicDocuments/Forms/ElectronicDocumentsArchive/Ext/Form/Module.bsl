////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtClientAtServerNoContext
Procedure SetFilterInListByItemClientServer(DataList, ItemKind, ItemValue)
	
	CommonUseClientServer.SetFilterDynamicListItem(DataList, ItemKind,
		ItemValue, DataCompositionComparisonType.Equal,, ValueIsFilled(ItemValue));
	
EndProcedure

&AtServer
Function IsArbitraryDocument(Object, ParametersStructure)
	
	If TypeOf(Object.FileOwner) = Type("DocumentRef.RandomED") Then
		ParametersStructure = New Structure("Object", Object.FileOwner);
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Procedure SetResponsibleED(Val ObjectList, NewResponsible, ProcessedEDCount)
	
	SetEDAttributeValue("Responsible", ObjectList, NewResponsible, ProcessedEDCount);
	
EndProcedure

&AtServer
Procedure SetEDAttributeValue(ParameterKind, Val ObjectList, Val ParameterValue, NumberOfProcessed)
	
	EDKindsArray = New Array();
	NumberOfProcessed = 0;
	
	For Each ListIt IN ObjectList Do
		If TypeOf(ListIt) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		EDKindsArray.Add(ListIt.Ref);
	EndDo;
	
	If EDKindsArray = 0 Then
		Return;
	EndIf;
	
	If ParameterKind = "Responsible" Then
		Query = New Query(
		"SELECT ALLOWED
		|	EDAttachedFiles.Ref,
		|	EDAttachedFiles.Responsible
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|WHERE
		|	EDAttachedFiles.Ref IN(&EDKindsArray)
		|	AND EDAttachedFiles.Responsible <> &Responsible");
		
		Query.SetParameter("EDKindsArray",      EDKindsArray);
		Query.SetParameter("Responsible", ParameterValue);
	Else
		Return;
	EndIf;
	
	Selection = Query.Execute().Select();
	
	BeginTransaction();
	
	While Selection.Next() Do
		
		Try
			LockDataForEdit(Selection.Ref);
		Except
			ErrorText = NStr("en='Unable to lock electronic document (%Object%). %ErrorDescription%';ru='Не удалось заблокировать электронный документ (%Объект%). %ОписаниеОшибки%'");
			ErrorText = StrReplace(ErrorText, "%Object%",         Selection.Ref);
			ErrorText = StrReplace(ErrorText, "%ErrorDescription%", BriefErrorDescription(ErrorInfo()));
			ErrorCommonText = ErrorCommonText+Chars.LF+ErrorText;
			RollbackTransaction();
			Raise ErrorText;
		EndTry;
		
		Try
		
			If ParameterKind = "Responsible" Then
				ParametersStructure = New Structure("Responsible", ParameterValue);
				ElectronicDocumentsServiceCallServer.ChangeByRefAttachedFile(Selection.Ref, ParametersStructure, False);
			EndIf;
			NumberOfProcessed = NumberOfProcessed + 1;
		Except
			ErrorText = NStr("en='Failed to write the electronic document (%Object%). %ErrorDescription%';ru='Не удалось выполнить запись электронного документа (%Объект%). %ОписаниеОшибки%'");
			ErrorText = StrReplace(ErrorText, "%Object%",         Selection.Ref);
			ErrorText = StrReplace(ErrorText, "%ErrorDescription%", BriefErrorDescription(ErrorInfo()));
			ErrorCommonText = ErrorCommonText+Chars.LF+ErrorText;
			RollbackTransaction();
			Raise ErrorText;
		EndTry
		
	EndDo;
	
	CommitTransaction();
	
EndProcedure

&AtClient
Procedure CompareEDData(CurrentList)
	
	#If Not ThickClientManagedApplication AND Not ThickClientOrdinaryApplication Then
		Message(NStr("en='Electronic documents matching can be performed only in the thick client mode.';ru='Сравнение электронных документов можно сделать только в режиме толстого клиента.'"));
		Return;
	#Else
		If CurrentList.CurrentData = Undefined
			OR CurrentList.SelectedRows.Count() <> 2 Then
			Return;
		EndIf;
		CurrentED    = CurrentList.SelectedRows.Get(0);
		LastEDVersion = CurrentList.SelectedRows.Get(1);
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("EDFirst", LastEDVersion);
		ParametersStructure.Insert("EDSecond", CurrentED);
		PerformEDComparison(ParametersStructure);
	#EndIf
	
EndProcedure

&AtServer
Procedure SetPackagesStatus(PackagesTable, PackageStatus, CountOfChanged)
	
	CountOfChanged = 0;
	For Each TableRow IN Items[PackagesTable].SelectedRows Do
		Try
			Package = TableRow.Ref.GetObject();
			Package.PackageStatus = PackageStatus;
			Package.Write();
			CountOfChanged = CountOfChanged + 1;
		Except
			MessageText = BriefErrorDescription(ErrorInfo());
			ErrorText = DetailErrorDescription(ErrorInfo());
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
				NStr("en='modification of ED packages status';ru='изменение статуса пакетов ЭД'"), ErrorText, MessageText);
		EndTry;
	EndDo;
	
EndProcedure

&AtServer
Function GetAttachedFilesOfEDPackagesAtServer(Val EDPackages)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDAttachedFiles.Ref
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileOwner IN (&FileOwners)";
	Query.SetParameter("FileOwners", EDPackages);
	
	QueryResult = Query.Execute().Unload();
	FilesArray = QueryResult.UnloadColumn("Ref");
	
	Return FilesArray;
	
EndFunction

&AtServer
Procedure PerformEDComparison(ParametersStructure)
	
	#If Not ThickClientManagedApplication AND Not ThickClientOrdinaryApplication Then
		MessageText = NStr("en='Electronic documents matching can be performed only in the thick client mode.';ru='Сравнение электронных документов можно сделать только в режиме толстого клиента.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	#Else
		
		EDFirst = ParametersStructure.EDFirst;
		EDSecond = ParametersStructure.EDSecond;
		
		If Not (ValueIsFilled(EDFirst) AND ValueIsFilled(EDSecond)) Then
			MessageText = NStr("en='No one of the compared electronic documents has been specified.';ru='Не указан один из сравниваемых электронных документов.'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
		
		EDKindsArray = New Array;
		EDKindsArray.Add(EDFirst);
		EDKindsArray.Add(EDSecond);
		TemporaryFilesList = ElectronicDocumentsService.PrepareEDViewTemporaryFiles(EDKindsArray);
		
		If TemporaryFilesList = Undefined Then
			MessageText = NStr("en='Error when parsing the electronic document.';ru='Ошибка при разборе электронного документа.'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
		
		FileName = ElectronicDocumentsService.TemporaryFileCurrentName("mxl");
		// It is necessary to replace fragment from the last underscore to fragment ".mxl"
		StringLength = StrLen(FileName);
		For ReverseIndex = 0 To StringLength Do
			If Mid(FileName, StringLength - ReverseIndex, 1) = "_" Then
				Break;
			EndIf;
		EndDo;
		
		EDName = TemporaryFilesList[0].EDName;
		FileNameCorrection(EDName);
		FirstMXLFileName = Left(FileName, StringLength - ReverseIndex) + EDName + Right(FileName, 4);
		SpreadsheetDocument = GetFromTempStorage(TemporaryFilesList[0].DataFileAddress);
		SpreadsheetDocument.Write(FirstMXLFileName);
		
		EDName = TemporaryFilesList[1].EDName;
		FileNameCorrection(EDName);
		SecondMXLFileName = Left(FileName, StringLength - ReverseIndex) + EDName + Right(FileName, 4);
		SpreadsheetDocument = GetFromTempStorage(TemporaryFilesList[1].DataFileAddress);
		SpreadsheetDocument.Write(SecondMXLFileName);
		
		Comparison = New FileComparison;
		Comparison.CompareMethod = FileCompareMethod.SpreadsheetDocument;
		Comparison.FirstFile = FirstMXLFileName;
		Comparison.SecondFile = SecondMXLFileName;
		Comparison.ShowDifferencesModally();
		
	#EndIf
	
EndProcedure

&AtServer
Procedure FileNameCorrection(StrFileName)
	
	// List of prohibited characters is taken from here: http://support.microsoft.com/kb/100108/ru.
	// Thus the forbidden symbols for file systems FAT and NTFS were integrated.
	StrException = """ / \ [ ] : ; | = , ? * < >";
	StrException = StrReplace(StrException, " ", "");
	
	For Ct=1 to StrLen(StrException) Do
		Char = Mid(StrException, Ct, 1);
		If Find(StrFileName, Char) <> 0 Then
			StrFileName = StrReplace(StrFileName, Char, " ");
		EndIf;
	EndDo;
	
	StrFileName = TrimAll(StrFileName);
	
EndProcedure

&AtServer
Procedure FilterByItemOnImportFromSettings(Form, DataList, ItemKind, Settings)
	
	ItemValue = Settings.Get(ItemKind);
	
	If ValueIsFilled(ItemValue) Then
		Form[ItemKind] = ItemValue;
		SetFilterInListByItemClientServer(DataList, ItemKind, ItemValue);
	EndIf;
	
	Settings.Delete(ItemKind);
	
EndProcedure

&AtClient
Procedure NotifyUserAboutResponsibleChange(NumberOfProcessed, ObjectList, Responsible)
	
	ClearMessages();
	
	If NumberOfProcessed > 0 Then
		
		ObjectList.Refresh();
		
		MessageText = NStr("en='For %NumberProcessed% from %TotalNumber% of
		|selected electronic documents responsible ""%Responsible%"" is set';ru='Для %КоличествоОбработанных% из %КоличествоВсего% выделенных эл.документов установлен ответственный ""%Ответственный%""'");
		MessageText = StrReplace(MessageText, "%NumberSelected%", NumberOfProcessed);
		MessageText = StrReplace(MessageText, "%CountTotal%",        ObjectList.SelectedRows.Count());
		MessageText = StrReplace(MessageText, "%Responsible%",          Responsible);
		HeaderText = NStr("en='Responsible ""%Responsible%"" is set';ru='Ответственный ""%Ответственный%"" установлен'");
		HeaderText = StrReplace(HeaderText, "%Responsible%", Responsible);
		ShowUserNotification(HeaderText, , MessageText, PictureLib.Information32);
		
	Else
		
		MessageText = NStr("en='Responsible ""%Responsible%"" is not set for any electronicdocument.';ru='Ответственный ""%Ответственный%"" не установлен ни для одного эл.документа.'");
		MessageText = StrReplace(MessageText, "%Responsible%", Responsible);
		HeaderText = NStr("en='Responsible ""%Responsible%"" is not set';ru='Ответственный ""%Ответственный%"" не установлен'");
		HeaderText = StrReplace(HeaderText, "%Responsible%", Responsible);
		ShowUserNotification(HeaderText,, MessageText, PictureLib.Information32);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportElectronicDocumentsForFTS(EDDirection)
	
	ParametersStructure = New Structure("EDDirection, CallVersion", EDDirection, 1);
	OpenForm("DataProcessor.ElectronicDocuments.Form.EDChoiceFormForFTSTransfer",
		ParametersStructure, ThisObject, UUID);
	
EndProcedure

&AtClient
Procedure ProcessSelectionResponsible(NewResponsible, AdditionalParameters) Export
	
	If ValueIsFilled(NewResponsible) Then
		ProcessedEDCount = 0;
		SetResponsibleED(Items.List.SelectedRows, NewResponsible,ProcessedEDCount);
		NotifyUserAboutResponsibleChange(ProcessedEDCount, Items.List, NewResponsible);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure SetResponsible(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("UserGroupChoice", False);
	FormParameters.Insert("CloseOnChoice",      True);
	FormParameters.Insert("ChoiceMode",             True);
	
	NotifyDescription = New NotifyDescription("ProcessSelectionResponsible", ThisObject);
	NewResponsible = OpenForm("Catalog.Users.ChoiceForm", FormParameters, ThisObject,
		UUID, , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure CompareEDDataInc(Command)
	
	CompareEDData(Items.List);
	
EndProcedure

&AtClient
Procedure CompareEDDataOutg(Command)
	
	CompareEDData(Items.ListOutg);
	
EndProcedure

&AtClient
Procedure Unpack(Command)
	
	// Extract only selected rows
	ElectronicDocumentsServiceClient.UnpackEDPackagesArray(Items.UnpackedPackages.SelectedRows);
	
EndProcedure

&AtClient
Procedure Send(Command)
	
	// Send only the selected rows
	EDKindsArray = Items.UnshippedPackages.SelectedRows; 
	
	NotificationProcessing = New NotifyDescription("CommandSendNotification", ThisObject);
	
	ElectronicDocumentsServiceClient.SendEDPackagesArray(EDKindsArray,NotificationProcessing);
	
EndProcedure

&AtClient
Procedure CommandSendNotification(SentPackagesCnt, AdditionalParameters) Export
	
	NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	NotificationText     = NStr("en='The sent packages are not present';ru='Отправленных пакетов нет'");
	
	If ValueIsFilled(SentPackagesCnt) Then
	
		NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Number of sent packages: (%1)';ru='Отправлено пакетов: (%1)'"), SentPackagesCnt);
	EndIf;
	
	ShowUserNotification(NotificationTitle, , NotificationText);
	
	
EndProcedure

&AtClient
Procedure SetStatusToUnpacking(Command)
	
	PackagesTable = "UnpackedPackages";
	Quantity = 0;
	SetPackagesStatus(PackagesTable, PredefinedValue("Enum.EDPackagesStatuses.ToUnpacking"), Quantity);
	
	NotificationText = NStr("en='Packages status is changed to ""To extract""';ru='Изменен статус пакетов на ""К распаковке""'") + ": (%1)";
	NotificationText = StrReplace(NotificationText, "%1", Quantity);
	
	ShowUserNotification(NStr("en='Electronic document exchange';ru='Обмен электронными документами'"), , NotificationText);
	Items[PackagesTable].Refresh();
	
EndProcedure

&AtClient
Procedure SetCancelStatus(Command)
	
	If Command.Name = "SetStatusUnpackedPackagesCanceled" Then
		PackagesTable = "UnpackedPackages";
	Else
		PackagesTable = "UnshippedPackages";
	EndIf;
	
	Quantity = 0;
	SetPackagesStatus(PackagesTable, PredefinedValue("Enum.EDPackagesStatuses.Canceled"), Quantity);
	NotificationText = NStr("en='Packages status is changed to ""Canceled""';ru='Изменен статус пакетов на ""Отменен""'") + ": (%1)";
	NotificationText = StrReplace(NotificationText, "%1", Quantity);
	ShowUserNotification(NStr("en='Electronic document exchange';ru='Обмен электронными документами'"), , NotificationText);
	Items[PackagesTable].Refresh();
	
EndProcedure

&AtClient
Procedure SetStatusPreparedToSending(Command)
	
	PackagesTable = "UnshippedPackages";
	Quantity = 0;
	SetPackagesStatus(PackagesTable, PredefinedValue("Enum.EDPackagesStatuses.PreparedToSending"), Quantity);
	NotificationText = NStr("en='Packages status is changed to ""Ready for sending""';ru='Изменен статус пакетов на ""Подготовлен к отправке""'" + ": (%1)");
	NotificationText = StrReplace(NotificationText, "%1", Quantity);
	ShowUserNotification(NStr("en='Electronic document exchange';ru='Обмен электронными документами'"), , NotificationText);
	Items[PackagesTable].Refresh();
	
EndProcedure

&AtClient
Procedure SaveEDPackagesToDisc(Command)
	
	AttachedFilesED = GetAttachedFilesOfEDPackagesAtServer(Items.AllPackages.SelectedRows);
	
	FilesArray = New Array;
	For Each AttachedFile IN AttachedFilesED Do
		FileData = ElectronicDocumentsServiceCallServer.GetFileData(AttachedFile, UUID);
		FileDescription = New TransferableFileDescription(
			FileData.FileName + ".zip", FileData.FileBinaryDataRef);
		FilesArray.Add(FileDescription);
	EndDo;
	
	If FilesArray.Count() Then
		EmptyProcessor = New NotifyDescription("EmptyProcessor", ElectronicDocumentsServiceClient);
		BeginGettingFiles(EmptyProcessor, FilesArray);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportIncomingElectronicDocumentsForFTS(Command)
	
	ExportElectronicDocumentsForFTS(PredefinedValue("Enum.EDDirections.Incoming"));
	
EndProcedure

&AtClient
Procedure OutgoingElectronicDocumentsExportForFTS(Command)
	
	ExportElectronicDocumentsForFTS(PredefinedValue("Enum.EDDirections.Outgoing"));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure EDKindOnChange(Item)
	
	SetFilterInListByItemClientServer(List, "EDKind", EDKind);
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	If Item.CurrentData <> Undefined AND Item.CurrentData.OurOperand Then
			NewStructure = Undefined;
			If IsArbitraryDocument(SelectedRow, NewStructure) Then
				OpenForm("Document.RandomED.Form.DocumentForm", NewStructure);
				Return;
			EndIf;
			
			ElectronicDocumentsServiceClient.OpenEDForViewing(SelectedRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure ResponsibleOnChange(Item)
	
	SetFilterInListByItemClientServer(List, "Responsible", Responsible);
	
EndProcedure

&AtClient
Procedure EDStatusOnChange(Item)
	
	SetFilterInListByItemClientServer(List, "EDStatus", EDStatus);
	
EndProcedure

&AtClient
Procedure UnpackedPackageCounterpartyOnChange(Item)
	
	SetFilterInListByItemClientServer(UnpackedPackages, "Counterparty", UnpackedPackageCounterparty);
	
EndProcedure

&AtClient
Procedure UnpackedPackageStatusOnChange(Item)
	
	SetFilterInListByItemClientServer(UnpackedPackages, "Status", UnpackedPackageStatus);
	
EndProcedure

&AtClient
Procedure UnsentPackageCounterpartyOnChange(Item)
	
	SetFilterInListByItemClientServer(UnshippedPackages, "Counterparty", UnshippedPackageCounterparty);
	
EndProcedure

&AtClient
Procedure UnsentPackageStatusOnChange(Item)
	
	SetFilterInListByItemClientServer(UnshippedPackages, "Status", UnshippedPackageStatus);
	
EndProcedure

&AtClient
Procedure ResponsibleOutgOnChange(Item)
	
	SetFilterInListByItemClientServer(ListOutg, "Responsible", ResponsibleOutg);
	
EndProcedure

&AtClient
Procedure EDKindOutgOnChange(Item)
	
	SetFilterInListByItemClientServer(ListOutg, "KindEDOutg", KindEDOutg);
	
EndProcedure

&AtClient
Procedure EDOutgStatusOnChange(Item)
	
	SetFilterInListByItemClientServer(ListOutg, "EDStatusOutg", EDStatusOutg);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Responsible = Users.AuthorizedUser();
	BankExchangeUsing = GetFunctionalOption("UseEDExchangeWithBanks");
	SetFilterInListByItemClientServer(List, "Responsible", Responsible);
	
	ResponsibleOutg = Responsible;
	SetFilterInListByItemClientServer(ListOutg, "Responsible", ResponsibleOutg);
	
	UnpackedPackageStatus = Enums.EDPackagesStatuses.ToUnpacking;
	SetFilterInListByItemClientServer(UnpackedPackages, "Status", UnpackedPackageStatus);
	
	UnshippedPackageStatus = Enums.EDPackagesStatuses.PreparedToSending;
	SetFilterInListByItemClientServer(UnshippedPackages, "Status", UnshippedPackageStatus);
	
	EDActualKinds = ElectronicDocumentsReUse.GetEDActualKinds();
	
	IncomingEDExceptionArray = New Array();
	IncomingEDExceptionArray.Add(Enums.EDKinds.PaymentOrder);
	IncomingEDExceptionArray.Add(Enums.EDKinds.QueryStatement);
	If Not BankExchangeUsing Then
		IncomingEDExceptionArray.Add(Enums.EDKinds.BankStatement);
	EndIf;
	KindsEDIncoming = CommonUseClientServer.ReduceArray(EDActualKinds, IncomingEDExceptionArray);
	Items.EDKind.ChoiceList.LoadValues(KindsEDIncoming);
	
	OutgoingEDExceptionArray = New Array();
	OutgoingEDExceptionArray.Add(Enums.EDKinds.BankStatement);
	OutgoingEDExceptionArray.Add(Enums.EDKinds.Confirmation);
	If Not BankExchangeUsing Then
		OutgoingEDExceptionArray.Add(Enums.EDKinds.QueryStatement);
		OutgoingEDExceptionArray.Add(Enums.EDKinds.PaymentOrder);
	EndIf;
	TypesOfEDOutgoing = CommonUseClientServer.ReduceArray(EDActualKinds, OutgoingEDExceptionArray);
	Items.KindEDOutg.ChoiceList.LoadValues(TypesOfEDOutgoing);
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterByItemOnImportFromSettings(ThisObject, List, "EDKind",    Settings);
	FilterByItemOnImportFromSettings(ThisObject, List, "EDStatus", Settings);
	
	FilterByItemOnImportFromSettings(ThisObject, ListOutg, "KindEDOutg",    Settings);
	FilterByItemOnImportFromSettings(ThisObject, ListOutg, "EDStatusOutg", Settings);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		
		Items.List.Refresh();
		Items.ListOutg.Refresh();
		Items.UnpackedPackages.Refresh();
		Items.UnshippedPackages.Refresh();
		Items.AllPackages.Refresh();
		
	EndIf;
	
EndProcedure














