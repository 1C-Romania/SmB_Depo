
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("FullFileName") Then
		ExportDriverFileName = Parameters.FullFileName;
	EndIf;
	
	AdditionalInformation = "";
	ProvidedApplication = Object.Predefined;
	
	If Not ValueIsFilled(Object.Ref) Then
		Object.SuppliedAsDistribution = True;
	EndIf;
	
	If Not ProvidedApplication AND Not IsBlankString(Object.DriverFileName) Then
		DriverLink = GetURL(Object.Ref, "ExportedDriver");
		DriverFileName = Object.DriverFileName;
	EndIf;
	
	Items.DriverFileName.Visible = Not ProvidedApplication;
	Items.DriverTemplateName.Visible = ProvidedApplication;
	Items.EquipmentType.ReadOnly = ProvidedApplication;
	Items.Description.ReadOnly = ProvidedApplication;
	Items.ObjectID.ReadOnly = ProvidedApplication;
	Items.ObjectID.InputHint = ?(ProvidedApplication, NStr("en='<Not specified>';ru='<Не указан>'"), 
		NStr("en='<ProgID of the component is not entered>';ru='<ProgID компоненты не введен>'"));
	Items.DriverTemplateName.InputHint = ?(ProvidedApplication, NStr("en='<Not specified>';ru='<Не указан>'"), "");
	
	Items.Save.Visible = Not ProvidedApplication;
	Items.WriteAndClose.Visible = Not ProvidedApplication;
	Items.FormClose.Visible =ProvidedApplication;
	Items.FormClose.DefaultButton = Items.FormClose.Visible;
		 
	// Import and install the driver from the available list layouts.
	For Each DriverLayout IN Metadata.CommonTemplates Do
		If Find(DriverLayout.Name, "Driver") > 0 Then
			Items.DriverTemplateName.ChoiceList.Add(DriverLayout.Name);
		EndIf;
	EndDo;  
	
	TextColor = StyleColors.FormTextColor;
	InstallationColor = StyleColors.FieldSelectionBackColor;
	ErrorColor = StyleColors.NegativeTextColor;

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not IsBlankString(ExportDriverFileName) Then
	#If Not WebClient Then
		ImportDriverFile(ExportDriverFileName);
	#EndIf
	Else
		UpdateItemsState();
	EndIf;
	
	If Not IsBlankString(Object.Ref) Then
		RefreshDriverStatus();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Get the file from storage and put it into object.
	If Not ProvidedApplication AND IsTempStorageURL(DriverLink) Then
		BinaryData = GetFromTempStorage(DriverLink);
		CurrentObject.ExportedDriver = New ValueStorage(BinaryData, New Deflation(5));
		CurrentObject.DriverFileName = DriverFileName;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If Not ProvidedApplication AND Not IsBlankString(Object.DriverFileName) Then
		DriverLink = GetURL(Object.Ref, "ExportedDriver");
		DriverFileName = Object.DriverFileName;
	EndIf;
	
	UpdateItemsState();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If IsBlankString(Object.EquipmentType) Then 
		Cancel = True;
		CommonUseClientServer.MessageToUser(NStr("en='Equipment type is not specified.';ru='Тип оборудования не указан.'")); 
		Return;
	EndIf;
	
	If IsBlankString(Object.Description) Then 
		Cancel = True;
		CommonUseClientServer.MessageToUser(NStr("en='Name is not specified.';ru='Наименование не указано.'")); 
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ExportDriverFileCommand(Command)
	
	If ProvidedApplication Then
		
		If IsBlankString(Object.DriverTemplateName) Then
			CommonUseClientServer.MessageToUser(NStr("en='Driver template name is not specified.';ru='Имя макета драйвера не указано.'"));
			Return;
		Else
			ExportDriverLayout();
		EndIf;
		
	Else 
		
		If IsBlankString(Object.DriverFileName) Then
			CommonUseClientServer.MessageToUser(NStr("en='Driver file is not imported.';ru='Файл драйвера не загружен.'"));
			Return;
		EndIf;
		
		If Modified Then
			Text = NStr("en='You can continue only after the data is saved.
		|Write data and continue?';ru='Продолжение операции возможно только после записи данных.
		|Записать данные и продолжить?'");
			Notification = New NotifyDescription("ExportDriverFileEnd", ThisObject);
			ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
		Else
			ExportDriverFile();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportDriverFileEnd(Result, Parameters)Export 
	
	If Result = DialogReturnCode.Yes Then
		If Modified AND Not Write() Then
			Return;
		EndIf;
		ExportDriverFile();
	EndIf;  
	
EndProcedure 

&AtClient
Procedure ImportDriverFileCommand(Command)
	
	#If WebClient Then
		ShowMessageBox(, NStr("en='This functionality is available only in thin and thick client mode.';ru='Данный функционал доступен только в режиме тонкого и толстого клиента.'"));
		Return;
	#EndIf
	
	Notification = New NotifyDescription("DriverFileChoiceEnd", ThisObject);
	EquipmentManagerClient.StartDriverFileSelection(Notification);
	
EndProcedure

&AtClient
Procedure InstallDriverCommand(Command)
	
	If Modified Then
		Text = NStr("en='You can continue only after the data is saved.
		|Write data and continue?';ru='Продолжение операции возможно только после записи данных.
		|Записать данные и продолжить?'");
		Notification = New NotifyDescription("SetupDriverEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
	Else
		SetupDriver();
	EndIf
	
EndProcedure

&AtClient
Procedure SetupDriverEnd(Result, Parameters) Export 
	
	If Result = DialogReturnCode.Yes Then
		If Modified AND Not Write() Then
			Return;
		EndIf;
		SetupDriver();
	EndIf;  
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure ReadInformationAboutDriver(FileInformation)
	
	XMLReader = New XMLReader;
	XMLReader.SetString(FileInformation);
	XMLReader.MoveToContent();
	
	If XMLReader.Name = "drivers" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
		While XMLReader.Read() Do 
			If XMLReader.Name = "component" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
				Object.ObjectID = XMLReader.AttributeValue("progid");
				Object.Description = XMLReader.AttributeValue("name");
				Object.DriverVersion = XMLReader.AttributeValue("version");
				TempEquipmentType = XMLReader.AttributeValue("type");
				If Not IsBlankString(TempEquipmentType) Then
					Object.EquipmentType = EquipmentManagerServerCall.GetEquipmentType(TempEquipmentType);
				EndIf;
			EndIf;
		EndDo;  
	EndIf;
	XMLReader.Close(); 
	
EndProcedure

&AtClient
Procedure ImportDriverFileWhenFinished(PlacedFiles, FileName) Export 
	
	If PlacedFiles.Count() > 0 Then
		DriverFileName = FileName;
		DriverLink = PlacedFiles[0].Location;
		UpdateItemsState();
	EndIf;
	
EndProcedure

#If Not WebClient Then

&AtClient
Procedure DriverFileChoiceEnd(FullFileName, Parameters) Export
	
	If Not IsBlankString(FullFileName) Then
		ImportDriverFile(FullFileName);
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDriverFile(FullFileName)
	
	TempDriverFile = New File(FullFileName);
	
	//If GetDriverInformationByFile(TempDriverFile.DescriptionFull) Then
	If GetDriverInformationByFile(TempDriverFile.FullName) Then
		Notification = New NotifyDescription("ImportDriverFileWhenFinished", ThisObject, TempDriverFile.Name);
		BeginPuttingFiles(Notification, Undefined, TempDriverFile.DescriptionFull, False) 
	EndIf;
	
EndProcedure

&AtClient
Function GetDriverInformationByFile(FullFileName) 
	
	Result = False;
	
	DriverFile = New File(FullFileName);
	FileExtension = Upper(DriverFile.Extension);
	
	If Not EquipmentManagerClientReUse.IsLinuxClient() AND FileExtension = ".EXE" Then
		
		// Driver file comes with distribution.
		Object.SuppliedAsDistribution = True; 
		Result = True;
		Return Result;
		
	ElsIf FileExtension = ".ZIP" Then
		
		DriverArchive = New ZipFileReader();
		DriverArchive.Open(FullFileName);
		
		For Each ArchiveItem IN DriverArchive.Items Do
			ManifestFound = False;
			
			// Check if there is manifest file.
			If Upper(ArchiveItem.Name) = "MANIFEST.XML" Then
				Object.SuppliedAsDistribution = False; 
				ManifestFound = True;
				Result = True;
			EndIf;
			
			// Check if there is information file.
			If Upper(ArchiveItem.Name) = "INFO.XML" Then
				TemporaryDirectory = TempFilesDir() + "cel\";
				DriverArchive.Extract(ArchiveItem, TemporaryDirectory);
				InformationFile = New TextReader(TemporaryDirectory + "INFO.XML", TextEncoding.UTF8);
				ReadInformationAboutDriver(InformationFile.Read());
				InformationFile.Close(); 
				BeginDeletingFiles(, TemporaryDirectory + "INFO.XML");
			EndIf;
			
			// Driver comes packaged in distribution archive.
			If Not EquipmentManagerClientReUse.IsLinuxClient() AND Not ManifestFound Then
				If (Upper(ArchiveItem.Name) = "SETUP.EXE" Or Upper(ArchiveItem.Name) = Upper(DriverFile.BaseName) + ".EXE") Then
					Object.SuppliedAsDistribution = True; 
					Result = True;
				EndIf;
			EndIf;
			
		EndDo;
		
		If IsBlankString(Object.ObjectID) Then
			Object.ObjectID = "AddIn.None";
		EndIf;
		
		Return Result;
		
	Else
		ShowMessageBox(, NStr("en='Invalid file extension.';ru='Неверное расширение файла.'"));
		Return Result;
	EndIf;

EndFunction

#EndIf

Procedure RefreshDriverCurrentStatus()
	
	If NewArchitecture AND IntegrationLibrary Then
		DriverCurrentStatus = NStr("en='Integration library is installed.';ru='Установлена интеграционная библиотека.'");
		DriverCurrentStatus = DriverCurrentStatus + ?(MainDriverIsSet, NStr("en='Basic supply of driver is installed.';ru='Установлена основная поставка драйвера.'"),
																					 NStr("en='Driver main supply is not installed.';ru='Основная поставка драйвера не установлена.'")); 
	Else
		DriverCurrentStatus = NStr("en='Installed on current computer.';ru='Установлен на текущем компьютере.'");
	EndIf;
	If Not IsBlankString(CurrentVersion) Then
		DriverCurrentStatus = DriverCurrentStatus + StrReplace(NStr("en=' (Version: %s)';ru=' (Версия: %s)'"), "%s", CurrentVersion);
	EndIf;
	
EndProcedure

&AtClient
Procedure GetVersionNumberEnd(ResultOfCall, CallParameters, AdditionalParameters) Export;
	
	If Not IsBlankString(ResultOfCall) Then
		CurrentVersion = ResultOfCall;
		RefreshDriverCurrentStatus();
	EndIf;
	
EndProcedure

&AtClient
Procedure GetDescriptionEnd(ResultOfCall, CallParameters, AdditionalParameters) Export;
	
	NewArchitecture = True;
	DriverDescription = CallParameters[0];
	DetailsDriver     = CallParameters[1];
	EquipmentType      = CallParameters[2]; 
	AuditInterface    = CallParameters[3];
	IntegrationLibrary  = CallParameters[4];
	MainDriverIsSet = CallParameters[5];
	URLExportDriver       = CallParameters[6];
	RefreshDriverCurrentStatus();
	
EndProcedure

&AtClient
Procedure GettingDriverObjectEnd(DriverObject, Parameters) Export
	
	If IsBlankString(Object.ObjectID) AND ProvidedApplication Then
		DriverCurrentStatus = NStr("en='Driver setup is not required.';ru='Установка драйвера не требуется.'");
	ElsIf IsBlankString(DriverObject) Then
		DriverCurrentStatus = NStr("en='It is not installed on the current computer. Type is not defined:';ru='Не установлен на текущем компьютере. Не определен тип:'") + Chars.NBSp + Object.ObjectID;
		Items.DriverCurrentStatus.TextColor = ErrorColor;
	Else
		Items.FormSetupDriver.Enabled = False;
		Items.DriverCurrentStatus.TextColor = InstallationColor;
		CurrentVersion = "";
		Try
			MethodNotification = New NotifyDescription("GetVersionNumberEnd", ThisObject);
			DriverObject.StartCallGetVersionNumber(MethodNotification);
		Except
		EndTry;
		
		Try
			NewArchitecture          = False;
			DriverDescription      = "";
			DetailsDriver          = "";
			EquipmentType           = "";
			IntegrationLibrary  = False;
			MainDriverIsSet = False;
			AuditInterface         = 1012;
			URLExportDriver       = "";
			MethodNotification = New NotifyDescription("GetDescriptionEnd", ThisObject);
			DriverObject.StartCallGetDescription(MethodNotification, DriverDescription, DetailsDriver, EquipmentType, AuditInterface, 
											IntegrationLibrary, MainDriverIsSet, URLExportDriver);
		Except
			RefreshDriverCurrentStatus()
		EndTry;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshDriverStatus();
	
	DriverData = New Structure();
	DriverData.Insert("HardwareDriver"       , Object.Ref);
	DriverData.Insert("AsConfigurationPart"      , Object.Predefined);
	DriverData.Insert("ObjectID"      , Object.ObjectID);
	DriverData.Insert("SuppliedAsDistribution" , Object.SuppliedAsDistribution);
	DriverData.Insert("DriverTemplateName"         , Object.DriverTemplateName);
	DriverData.Insert("DriverFileName"          , Object.DriverFileName);
	
	Items.DriverCurrentStatus.TextColor = TextColor;
	
	Notification = New NotifyDescription("GettingDriverObjectEnd", ThisObject);
	EquipmentManagerClient.StartReceivingDriverObject(Notification, DriverData);
	
EndProcedure

&AtClient
Procedure UpdateItemsState();
	
	If ProvidedApplication AND IsBlankString(Object.DriverTemplateName) Then
		VisibleExportFile = False;
	ElsIf Not ProvidedApplication AND IsBlankString(DriverFileName) Then
		VisibleExportFile = False;
	Else
		VisibleExportFile = Not IsBlankString(Object.Ref);
	EndIf;
		
	Items.FormExportDriverFile.Visible = VisibleExportFile;
	Items.FormSetupDriver.Visible     = VisibleExportFile;
	//===============================
	//©# (Begin)	AlekS [2016-09-28]
	//Items.FormExportDriverFile.Visible = Not ProvidedApplication;
	Items.FormImportDriverFile.Visible = Not ProvidedApplication;
	//©# (End)		AlekS [2016-09-28]
	//===============================
	
	If Not IsBlankString(DriverFileName) Or ProvidedApplication Then
		If IsBlankString(Object.ObjectID) Then
			AdditionalInformation = NStr("en='ProgID of the component is not specified or driver installation is not required.';ru='Не указан ProgID компоненты или установка драйвера не требуется.'");
		ElsIf Object.SuppliedAsDistribution Then
			AdditionalInformation = NStr("en='Driver comes in the form of supplier distribution.';ru='Драйвер поставляется в виде дистрибутива поставщика.'");
		Else
			AdditionalInformation = NStr("en='Driver comes in the form of component in the archive.';ru='Драйвер поставляется в виде компоненты в архиве.'") +
				?(IsBlankString(Object.DriverVersion), "", Chars.LF + NStr("en='Component version in the archive:';ru='Версия компоненты в архиве:'") + Chars.NBSp + Object.DriverVersion);
		EndIf;
	Else
		AdditionalInformation = NStr("en='Connection of driver installed on local computers.';ru='Подключение установленного драйвера на локальных компьютерах.'");
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportDriverLayout()
	
	FileTempName = ?(IsBlankString(Object.DriverFileName), Object.DriverTemplateName + ".zip", Object.DriverFileName);
	If Upper(Right(FileTempName, 4)) = ".EXE" Then  
		FileTempName = Left(FileTempName, StrLen(FileTempName) - 4) + ".zip";  
	EndIf;
	FileReference = EquipmentManagerServerCall.GetTemplateFromServer(Object.DriverTemplateName);
	GetFile(FileReference, FileTempName); 
	
EndProcedure

&AtClient
Procedure ExportDriverFile()
	
	FileReferenceWIB = GetURL(Object.Ref, "ExportedDriver");
	GetFile(FileReferenceWIB, Object.DriverFileName); 
	
EndProcedure

&AtClient
Procedure SetDriverFromArchiveOnEnd(Result) Export 
	
	CommonUseClientServer.MessageToUser(NStr("en='Driver is installed.';ru='Установка драйвера завершена.'")); 
	RefreshDriverStatus();
	
EndProcedure 

&AtClient
Procedure SettingDriverFromDistributionOnEnd(Result, Parameters) Export 
	
	If Result Then
		CommonUseClientServer.MessageToUser(NStr("en='Driver is installed.';ru='Установка драйвера завершена.'")); 
		RefreshDriverStatus();
	Else
		CommonUseClientServer.MessageToUser(NStr("en='An error occurred when installing the driver from distribution.';ru='При установке драйвера из дистрибутива произошла ошибка.'")); 
	EndIf;

EndProcedure 

&AtClient
Procedure SetupDriver()
	
	ClearMessages();
	
	NotificationsDriverFromDistributionOnEnd = New NotifyDescription("SettingDriverFromDistributionOnEnd", ThisObject);
	NotificationsDriverFromArchiveOnEnd = New NotifyDescription("SetDriverFromArchiveOnEnd", ThisObject);
	
	EquipmentManagerClient.SetupDriver(Object.Ref, NotificationsDriverFromDistributionOnEnd, NotificationsDriverFromArchiveOnEnd);
	
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
