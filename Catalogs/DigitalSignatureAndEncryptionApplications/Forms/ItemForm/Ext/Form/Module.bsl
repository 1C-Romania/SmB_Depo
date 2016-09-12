
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If CommonUse.IsSubordinateDIBNode() Then
		ReadOnly = True;
	EndIf;
	
	SuppliedSettings = Catalogs.DigitalSignatureAndEncryptionApplications.SuppliedApllicationSettings();
	For Each SuppliedSetup IN SuppliedSettings Do
		Items.Description.ChoiceList.Add(SuppliedSetup.Presentation);
	EndDo;
	Items.Description.ChoiceList.Add("", NStr("en='<Another application>';ru='<Другая программа>'"));
	
	// Filling a new object according to the supplied setting.
	If Not ValueIsFilled(Object.Ref) Then
		Filter = New Structure("ID", Parameters.SuppliedSettingsID);
		Rows = SuppliedSettings.FindRows(Filter);
		If Rows.Count() > 0 Then
			FillPropertyValues(Object, Rows[0]);
			Object.Description = Rows[0].Presentation;
			Items.Description.ReadOnly = True;
			Items.ApplicationName.ReadOnly = True;
			Items.ApplicationType.ReadOnly = True;
		EndIf;
	EndIf;
	
	// Filling algorithms lists.
	Filter = New Structure("ApplicationName, ApplicationType", Object.ApplicationName, Object.ApplicationType);
	Rows = SuppliedSettings.FindRows(Filter);
	SuppliedSetup = ?(Rows.Count() = 0, Undefined, Rows[0]);
	FillAlgorithmChoiceLists(SuppliedSetup);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillSelectedProgramAlgorithms();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// It is needed to update
	// the list of applications and their parameters on the server and on the client.
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_DigitalSignatureAndEncryptionApplications", New Structure, Object.Ref);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.SetParameter("Ref", Object.Ref);
	Query.SetParameter("ApplicationName", Object.ApplicationName);
	Query.SetParameter("ApplicationType", Object.ApplicationType);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionApplications AS DigitalSignatureAndEncryptionApplications
	|WHERE
	|	DigitalSignatureAndEncryptionApplications.Ref <> &Ref
	|	AND DigitalSignatureAndEncryptionApplications.ApplicationName = &ApplicationName
	|	AND DigitalSignatureAndEncryptionApplications.ApplicationType = &ApplicationType";
	
	If Not Query.Execute().IsEmpty() Then
		Cancel = True;
		CommonUseClientServer.MessageToUser(
			NStr("en='A application with such name and type has been already added to the list.';ru='Программа с указанным именем и типом уже добавлена в список.'"),
			,
			"Object.ApplicationName");
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	
	FillSelectedApplicationSettings(Object.Description);
	FillSelectedProgramAlgorithms();
	
EndProcedure

&AtClient
Procedure DescriptionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	ModuleInformation = Undefined;
	
	If ValueSelected = "" Then
		Object.Description = "";
		Object.ApplicationName = "";
		Object.ApplicationType = "";
		Object.SignAlgorithm = "";
		Object.HashAlgorithm = "";
		Object.EncryptionAlgorithm = "";
	EndIf;
	
	FillSelectedApplicationSettings(ValueSelected);
	FillSelectedProgramAlgorithms();
	
EndProcedure

&AtClient
Procedure ApplicationNameOnChange(Item)
	
	FillSelectedProgramAlgorithms();
	
EndProcedure

&AtClient
Procedure ApplicationTypeOnChange(Item)
	
	FillSelectedProgramAlgorithms();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SetDeletionMark(Command)
	
	If Not Modified Then
		SetDeletionMarkEnd();
		Return;
	EndIf;
	
	ShowQueryBox(
		New NotifyDescription("SetDeletionMarkAfterReplyingToQuestion", ThisObject),
		NStr("en='To set the deletion mark you have to save your changes."
"Write the data?';ru='Для установки отметки удаления необходимо записать внесенные Вами изменения."
"Записать данные?'"), QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillSelectedApplicationSettings(Presentation)
	
	SuppliedSettings = Catalogs.DigitalSignatureAndEncryptionApplications.SuppliedApllicationSettings();
	
	SuppliedSetup = SuppliedSettings.Find(Presentation, "Presentation");
	If SuppliedSetup <> Undefined Then
		FillPropertyValues(Object, SuppliedSetup);
		Object.Description = SuppliedSetup.Presentation;
	EndIf;
	
	FillAlgorithmChoiceLists(SuppliedSetup);
	
EndProcedure

&AtServer
Procedure FillAlgorithmChoiceLists(SuppliedSetup)
	
	SuppliedSigningAlgorithms.Clear();
	SuppliedHashingAlgorithms.Clear();
	SuppliedEncryptionAlgorithms.Clear();
	
	If SuppliedSetup = Undefined Then
		Return;
	EndIf;
	
	SuppliedSigningAlgorithms.LoadValues(SuppliedSetup.SignAlgorithms);
	SuppliedHashingAlgorithms.LoadValues(SuppliedSetup.HashAlgorithms);
	SuppliedEncryptionAlgorithms.LoadValues(SuppliedSetup.EncryptAlgorithms);
	
EndProcedure

&AtClient
Procedure FillSelectedProgramAlgorithms()
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	BeginAttachingCryptoExtension(New NotifyDescription(
		"FillSelectedProgramAlgorithmsAfterConnectingWorkWithCryptographyExpansion", ThisObject));
	
EndProcedure

// Continuing the FillSelectedApplicationAlgorithms procedure.
&AtClient
Procedure FillSelectedProgramAlgorithmsAfterConnectingWorkWithCryptographyExpansion(Attached, Context) Export
	
	If Not Attached Then
		FillSelectedProgramAlgorithmsAfterReceivingInformation(Undefined, Context);
		Return;
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		PathToApplication = DigitalSignatureClientServer.PersonalSettings(
			).PathToDigitalSignatureAndEncryptionApplications.Get(Object.Ref);
	Else
		PathToApplication = "";
	EndIf;
	
	CryptoTools.BeginGettingCryptoModuleInformation(New NotifyDescription(
			"FillSelectedProgramAlgorithmsAfterReceivingInformation", ThisObject, ,
			"FillSelectedProgramAlgorithmsAfterInformationReceptionError", ThisObject),
		Object.ApplicationName, PathToApplication, Object.ApplicationType);
	
EndProcedure

// Continuing the FillSelectedApplicationAlgorithms procedure.
&AtClient
Procedure FillSelectedProgramAlgorithmsAfterInformationReceptionError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	FillSelectedProgramAlgorithmsAfterReceivingInformation(Undefined, Context);
	
EndProcedure

// Continuing the FillSelectedApplicationAlgorithms procedure.
&AtClient
Procedure FillSelectedProgramAlgorithmsAfterReceivingInformation(ModuleInformation, Context) Export
	
	// If the cryptography manager is not available and
	// is not supplied, algorithm names are to be filled manually.
	
	If ModuleInformation <> Undefined
	   AND Object.ApplicationName <> ModuleInformation.Name
	   AND Not CommonUseClientServer.IsLinuxClient() Then
		
		ModuleInformation = Undefined;
	EndIf;
	
	If ModuleInformation = Undefined Then
		Items.SignAlgorithm.ChoiceList.LoadValues(
			SuppliedSigningAlgorithms.UnloadValues());
		
		Items.HashAlgorithm.ChoiceList.LoadValues(
			SuppliedHashingAlgorithms.UnloadValues());
		
		Items.EncryptionAlgorithm.ChoiceList.LoadValues(
			SuppliedEncryptionAlgorithms.UnloadValues());
	Else
		Items.SignAlgorithm.ChoiceList.LoadValues(
			New Array(ModuleInformation.SignAlgorithms));
		
		Items.HashAlgorithm.ChoiceList.LoadValues(
			New Array(ModuleInformation.HashAlgorithms));
		
		Items.EncryptionAlgorithm.ChoiceList.LoadValues(
			New Array(ModuleInformation.EncryptAlgorithms));
	EndIf;
	
	Items.SignAlgorithm.DropListButton =
		Items.SignAlgorithm.ChoiceList.Count() <> 0;
	
	Items.HashAlgorithm.DropListButton =
		Items.HashAlgorithm.ChoiceList.Count() <> 0;
	
	Items.EncryptionAlgorithm.DropListButton =
		Items.EncryptionAlgorithm.ChoiceList.Count() <> 0;
	
EndProcedure

&AtClient
Procedure SetDeletionMarkAfterReplyingToDoQueryBox(Response, NotSpecified) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	If Not Write() Then
		Return;
	EndIf;
	
	SetDeletionMarkEnd();
	
EndProcedure
	
&AtClient
Procedure SetDeletionMarkEnd()
	
	Object.DeletionMark = Not Object.DeletionMark;
	Write();
	
	Notify("Write_DigitalSignatureAndEncryptionApplications", New Structure, Object.Ref);
	
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
