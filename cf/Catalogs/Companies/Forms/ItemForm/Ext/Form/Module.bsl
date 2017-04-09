
#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) And Not GetFunctionalOption("UseSeveralCompanies") Then
		ErrorText = NStr("ru = 'Запрещено создавать новую организацию
								|при выключенной настройке параметра учета ""Учет по нескольким организациям"".'; en = 'It is forbidden to create a new company
								|with the off parameter setting accounting ""Use several companies""'");
		Raise ErrorText;
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		
		GenerateDescriptionAutomatically = True;
		
		// SB.ContactInformation
		ContactInformationSB.OnCreateOnReadAtServer(ThisObject);
		// End SB.ContactInformation
		
		SetAllTitlesCollapsedDisplay(ThisObject);
		
		If ValueIsFilled(Object.Individual) Then
			ReadIndividual(Object.Individual);
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(Object.Individual) Then
		Items.Surname.AutoChoiceIncomplete		= Undefined;
		Items.FirstName.AutoChoiceIncomplete	= Undefined;
		Items.MiddleName.AutoChoiceIncomplete	= Undefined;
	EndIf;
	
	IsWebClient = CommonUseClientServer.ThisIsWebClient();
	Items.CommandBarLogo.Visible		= IsWebClient;
	Items.CommandBarFacsimile.Visible	= IsWebClient;
	
	FormManagement(ThisObject);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.PrintCommands);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributes");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.AttachedFiles"
		AND ValueIsFilled(ValueSelected) Then
		
		If WorkWithLogo Then
			
			Object.LogoFile = ValueSelected;
			BinaryPictureData = SmallBusinessServer.ReferenceToBinaryFileData(Object.LogoFile, UUID);
			If BinaryPictureData <> Undefined Then
				AddressLogo = BinaryPictureData;
			EndIf;
			
		ElsIf WorkWithFacsimile Then
			
			Object.FileFacsimilePrinting = ValueSelected;
			BinaryPictureData = SmallBusinessServer.ReferenceToBinaryFileData(Object.FileFacsimilePrinting, UUID);
			If BinaryPictureData <> Undefined Then
				AddressFaxPrinting = BinaryPictureData;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingMainAccount" And Parameter.Owner = Object.Ref Then
		
		Object.BankAccountByDefault = Parameter.NewMainAccount;
		ReadBankAccountByDefault(Object.BankAccountByDefault);
		If Not Modified Then
			Write();
		EndIf;
		Notify("SettingMainAccountCompleted");
		
	ElsIf EventName = "Record_AttachedFile" Then
		
		Modified	= True;
		If WorkWithLogo Then
			
			Object.LogoFile = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
			BinaryPictureData = SmallBusinessServer.ReferenceToBinaryFileData(Object.LogoFile, UUID);
			If BinaryPictureData <> Undefined Then
				AddressLogo = BinaryPictureData;
			EndIf;
			WorkWithLogo = False;
			
		ElsIf WorkWithFacsimile Then
			
			Object.FileFacsimilePrinting = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
			BinaryPictureData = SmallBusinessServer.ReferenceToBinaryFileData(Object.FileFacsimilePrinting, UUID);
			If BinaryPictureData <> Undefined Then
				AddressFaxPrinting = BinaryPictureData;
			EndIf;
			WorkWithFacsimile = False;
			
		EndIf;
		
	ElsIf EventName = "Write_Individuals" And Source <> Object.Ref And Parameter = Object.Individual Then
		
		ReadIndividual(Parameter);
		
	EndIf;
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If ValueIsFilled(CurrentObject.LogoFile) Then
		BinaryPictureData = SmallBusinessServer.ReferenceToBinaryFileData(CurrentObject.LogoFile, UUID);
		If BinaryPictureData <> Undefined Then
			AddressLogo = BinaryPictureData;
		EndIf;
	EndIf;
	
	If ValueIsFilled(CurrentObject.FileFacsimilePrinting) Then
		BinaryPictureData = SmallBusinessServer.ReferenceToBinaryFileData(CurrentObject.FileFacsimilePrinting, UUID);
		If BinaryPictureData <> Undefined Then
			AddressFaxPrinting = BinaryPictureData;
		EndIf;
	EndIf;
	
	If CurrentObject.LegalEntityIndividual = Enums.CounterpartyKinds.Individual Then
		ReadIndividual(CurrentObject.Individual);
	EndIf;
	
	ReadBankAccountByDefault(CurrentObject.BankAccountByDefault);
	
	GenerateDescriptionAutomatically	= IsBlankString(Object.Description);
	
	// SB.ContactInformation
	ContactInformationSB.OnCreateOnReadAtServer(ThisObject);
	// End SB.ContactInformation
	
	// The algorithm of formation of the contact header information depends on the legal address. It should be called after SB.ContactInformation
	SetAllTitlesCollapsedDisplay(ThisObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Save previous values for further analysis
	CurrentObject.AdditionalProperties.Insert("PreviousCompanyKind", CommonUse.ObjectAttributeValue(CurrentObject.Ref, "LegalEntityIndividual"));
	CurrentObject.AdditionalProperties.Insert("IsNew", CurrentObject.IsNew());
	
	// Fill main bank account
	SetBankAccountByDefault(CurrentObject);
	
	// An individual will be created in OnWrite()
	If CurrentObject.LegalEntityIndividual = Enums.CounterpartyKinds.Individual And Not ValueIsFilled(CurrentObject.Individual) Then
		CurrentObject.Individual = Catalogs.Individuals.GetRef();
	EndIf;
	
	// SB.ContactInformation
	ContactInformationSB.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End SB.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // BeforeWriteAtServer()

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteBankAccountByDefault(CurrentObject);
	WriteIndividual(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ReadIndividual(CurrentObject.Individual);
	
	SetAllTitlesCollapsedDisplay(ThisObject);
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_Companies", Object.Ref, Object.Ref);
	If Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyKinds.Individual") Then
		Notify("Write_Individuals", Object.Individual, Object.Ref);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.LegalEntityIndividual = Enums.CounterpartyKinds.Individual Then
		If Not ValueIsFilled(IndividualFullName.Surname) 
			And Not ValueIsFilled(IndividualFullName.Name) 
			And Not ValueIsFilled(IndividualFullName.Patronymic) Then
			
			MessageText = NStr("ru = 'Не заполнено ФИО'; en = 'Is not filled full name'");
			CommonUseClientServer.MessageToUser(MessageText, ,	"Surname", "IndividualFullName", Cancel);
		EndIf;
	EndIf;
	
	If Not IsBlankString(MainAccount_Number) And Not ValueIsFilled(MainAccount_Bank) Then
		MessageText = CommonUseClientServer.TextFillingErrors(, "Filling", NStr("ru = 'Банк'; en = 'Bank'"));
		CommonUseClientServer.MessageToUser(MessageText, , "MainAccount_Bank", , Cancel);
	EndIf;
	
	If ValueIsFilled(MainAccount_Bank) And IsBlankString(MainAccount_Number) Then
		MessageText = CommonUseClientServer.TextFillingErrors(, "Filling", NStr("ru = 'Номер счета'; en = 'Account number'"));
		CommonUseClientServer.MessageToUser(MessageText, , "MainAccount_Number", , Cancel);
	EndIf;
	
	// SB.ContactInformation
	ContactInformationSB.FillCheckProcessingAtServer(ThisObject, Cancel);
	// End SB.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure PrefixOnChange(Item)
	
	If StrFind(Object.Prefix, "-") > 0 Then
		
		ShowMessageBox(Undefined, NStr("ru = 'Нельзя в префиксе организации использовать символ ""-"".'; en = 'It is impossible to use the symbol ""-"" in the prefix of company'"));
		Object.Prefix = StrReplace(Object.Prefix, "-", "");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DescriptionFullOnChange(Item)
	
	If GenerateDescriptionAutomatically Then
		Object.Description	= Object.DescriptionFull;
	EndIf;

EndProcedure

&AtClient
Procedure LegalEntityIndividualOnChange(Item)
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure IndividualFullNameOnChange(Item)
	
	If Not LockIndividualOnEdit() Then
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure BankStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("Catalog.Banks.ChoiceForm",, Item);
	
EndProcedure

&AtClient
Procedure BankCreating(Item, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("Catalog.Banks.ObjectForm",, Item);
	
EndProcedure

&AtClient
Procedure PettyCashByDefaultOnChange(Item)
	
	SetTitlePettyCash(ThisObject);
	
EndProcedure

&AtClient
Procedure TINOnChange(Item)
	
	SetTitleLegalData(ThisObject);
	
EndProcedure

&AtClient
Procedure RegistrationNumberOnChange(Item)
	
	SetTitleLegalData(ThisObject);
	
EndProcedure

&AtClient
Procedure AddressLogoClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	PicturesFlagsManagement(True, False);
	AddImageAtClient();
	
EndProcedure

&AtClient
Procedure AddressFaxPrintingClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	PicturesFlagsManagement(False, True);
	AddImageAtClient();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure PreviewPrintedFormProformaInvoice(Command)
	
	PrintManagementClient.ExecutePrintCommand(
		"Catalog.Companies",
		"PreviewPrintedFormProformaInvoice",
		CommonUseClientServer.ValueInArray(Object.Ref),
		ThisObject,
		New Structure);
	
EndProcedure

&AtClient
Procedure AddImageLogo(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select the image it is necessary to record the object. Write?'; ru = 'Для выбора изображения необходимо записать объект. Записать?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddLogoImageEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddLogoImageFragment();
	
EndProcedure

&AtClient
Procedure ChangeImageLogo(Command)
	
	ClearMessages();
	
	If ValueIsFilled(Object.LogoFile) Then
		
		AttachedFilesClient.OpenAttachedFileForm(Object.LogoFile);
		
	Else
		
		MessageText = NStr("en = 'Picture for editing is absent';ru = 'Отсутстует изображение для редактирования'");
		CommonUseClientServer.MessageToUser(MessageText,, "AddressLogo");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearImageLogo(Command)
	
	Object.LogoFile = Undefined;
	AddressLogo = "";
	
EndProcedure // ClearLogoImage()

&AtClient
Procedure LogoOfAttachedFiles(Command)
	
	PicturesFlagsManagement(True, False);
	ChoosePictureFromAttachedFiles();
	
EndProcedure // SelectImageFromAttachedFiles()

&AtClient
Procedure AddImageFacsimile(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select the image it is necessary to record the object. Write?'; ru = 'Для выбора изображения необходимо записать объект. Записать?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddFacsimileImageEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddFacsimileImageFragment();
	
EndProcedure

&AtClient
Procedure ChangeImageFacsimile(Command)
	
	ClearMessages();
	
	If ValueIsFilled(Object.FileFacsimilePrinting) Then
		
		AttachedFilesClient.OpenAttachedFileForm(Object.FileFacsimilePrinting);
		
	Else
		
		MessageText = NStr("en = 'Picture for editing is absent'; ru = 'Отсутстует изображение для редактирования'");
		CommonUseClientServer.MessageToUser(MessageText,, "AddressLogo");
		
	EndIf;
	
EndProcedure // ChangeFacsimileImage()

&AtClient
Procedure ClearImageFacsimile(Command)
	
	Object.FileFacsimilePrinting = Undefined;
	AddressFaxPrinting = "";
	
EndProcedure // ClearImageFacsimile()

&AtClient
Procedure FacsimileOfAttachedFiles(Command)
	
	PicturesFlagsManagement(False, True);
	ChoosePictureFromAttachedFiles();
	
EndProcedure // FacsimileFromAttachedFiles()

#EndRegion

#Region OtherProceduresAndFunctions

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	Object = Form.Object;
	
	// Set visibility of form items depending on the type of company
	If Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyKinds.LegalEntity") Then
		
		Items.GroupFullName.Visible	= False;
	Else
		
		Items.GroupFullName.Visible	= True;
	EndIf;
	
EndProcedure

#EndRegion

#Region BankAccountByDefault

&AtServer
Procedure ReadBankAccountByDefault(BankAccountByDefault)
	
	If ValueIsFilled(BankAccountByDefault) Then
		AttributesValues = CommonUse.ObjectAttributesValues(BankAccountByDefault, "Bank, AccountNo");
		MainAccount_Bank	= AttributesValues.Bank;
		MainAccount_Number	= AttributesValues.AccountNo;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetBankAccountByDefault(CurrentObject)
	
	If Not ValueIsFilled(MainAccount_Bank)
		Or IsBlankString(MainAccount_Number) Then
		
		Return;
	EndIf;
	
	If CurrentObject.IsNew() Then
	// If a new company, it is necessary to create a new bank account
		NeedCreateNew = True;
	Else
	// For existing company, it is necessary to check the bank account with the same key fields
	
		Query = New Query;
		Query.Text = "SELECT TOP 1
		             |	BankAccounts.Ref
		             |FROM
		             |	Catalog.BankAccounts AS BankAccounts
		             |WHERE
		             |	BankAccounts.Owner = &Owner
		             |	AND BankAccounts.Bank = &Bank
		             |	AND BankAccounts.AccountNo = &AccountNo";
		
		Query.SetParameter("Owner",		CurrentObject.Ref);
		Query.SetParameter("Bank",		MainAccount_Bank);
		Query.SetParameter("AccountNo",	MainAccount_Number);
		
		SetPrivilegedMode(True);
		QueryResult = Query.Execute();
		SetPrivilegedMode(False);
		
		If QueryResult.IsEmpty() Then
			// No bank account with such key fields
			If ValueIsFilled(CurrentObject.BankAccountByDefault) Then
				// Modifies an existing main account
				NeedCreateNew = False;
			Else
				// A new
				NeedCreateNew = True;
			EndIf;
		Else
			// The bank account is, set it as the main
			NeedCreateNew = False;
			
			Selection = QueryResult.Select();
			Selection.Next();
			CurrentObject.BankAccountByDefault = Selection.Ref;
		EndIf;
		
	EndIf;
	
	If NeedCreateNew Then
		CurrentObject.BankAccountByDefault = Catalogs.BankAccounts.GetRef();
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteBankAccountByDefault(CurrentObject)
	
	If Not ValueIsFilled(MainAccount_Bank)
		Or IsBlankString(MainAccount_Number) Then
		
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BankAccountObject = CurrentObject.BankAccountByDefault.GetObject();
	
	If BankAccountObject = Undefined Then
		
		// Creating
		BankAccountObject = Catalogs.BankAccounts.CreateItem();
		BankAccountObject.SetNewObjectRef(CurrentObject.BankAccountByDefault);
		BankAccountObject.Fill(CurrentObject.Ref);
		
	EndIf;
	
	// Alteration
	BankAccountObject.Bank = MainAccount_Bank;
	BankAccountObject.AccountNo = MainAccount_Number;
	BankAccountObject.GenerateDescription();
	
	// Record object
	BankAccountObject.Write();
	
	SetPrivilegedMode(False);
	
EndProcedure

#EndRegion

#Region Individual

&AtServer
Procedure ReadIndividual(Individual)
	
	If Not ValueIsFilled(Individual) Then
		Return;
	EndIf;
	
	ValueToFormAttribute(Individual.GetObject(), "Individual");
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	IndividualsDescriptionFullSliceLast.Period AS Period,
		|	IndividualsDescriptionFullSliceLast.Ind AS Ind
		|FROM
		|	InformationRegister.IndividualsDescriptionFull.SliceLast(, Ind = &Ind) AS IndividualsDescriptionFullSliceLast";
	
	Query.SetParameter("Ind", Individual);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		RecordManager = InformationRegisters.IndividualsDescriptionFull.CreateRecordManager();
		FillPropertyValues(RecordManager, Selection);
		RecordManager.Read();
		ValueToFormAttribute(RecordManager, "IndividualFullName");
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteIndividual(CurrentObject)
	
	If Object.LegalEntityIndividual <> Enums.CounterpartyKinds.Individual Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(IndividualFullName.Period) Тогда
		IndividualFullName.Period = '19800101';
	EndIf;
	If Not ValueIsFilled(IndividualFullName.Ind) Then
		IndividualFullName.Ind = CurrentObject.Individual;
	EndIf;
	RecordManager = FormAttributeToValue("IndividualFullName");
	RecordManager.Write();
	
	Individual.Description = IndividualFullName.Surname
		+ ?(IsBlankString(IndividualFullName.Name), "", " " + IndividualFullName.Name)
		+ ?(IsBlankString(IndividualFullName.Patronymic), "", " " + IndividualFullName.Patronymic);
	
	IndividualObject = FormAttributeToValue("Individual");
	If IndividualObject.Ref.IsEmpty() Then
		IndividualObject.SetNewObjectRef(CurrentObject.Individual);
	EndIf;
	IndividualObject.Write();
	
EndProcedure

&AtClient
Function LockIndividualOnEdit()
	
	If Not Parameters.Key.IsEmpty() And Not IndividualLocked Then
		If Not LockIndividualOnEditAtServer() Then
			ShowMessageBox(, NStr("ru='Не удается внести изменения в личные данные физического лица. Возможно данные редактируются другим пользователем.'; en = 'You can not make changes to the personal data of an individual. Perhaps the data is edited by another user.'"));
			ReadIndividual(Object.Individual);
			Return False;
		Else
			IndividualLocked = True;
			Return True;
		EndIf;
	Else
		Return True;
	EndIf;
	
EndFunction

&AtServer
Функция LockIndividualOnEditAtServer()
	
	Try
		LockDataForEdit(Individual.Ref, Individual.DataVersion, UUID);
		Return True;
	Except
		Return False;
	EndTry;
	
EndFunction

#EndRegion

#Region FacsimileAndLogo

&AtServerNoContext
Function GetFileData(PictureFile, UUID)
	
	Return AttachedFiles.GetFileData(PictureFile, UUID);
	
EndFunction

&AtClient
Procedure PicturesFlagsManagement(ThisIsWorkingWithLogo = False, ThisIsWorkingWithFacsimile = False)
	
	WorkWithLogo		= ThisIsWorkingWithLogo;
	WorkWithFacsimile	= ThisIsWorkingWithFacsimile;
	
EndProcedure

&AtClient
Procedure SeeAttachedFile()
	
	ClearMessages();
	
	AnObjectsNameAttribute = "";
	
	If WorkWithLogo Then
		
		AnObjectsNameAttribute = "LogoFile";
		
	ElsIf WorkWithFacsimile Then
		
		AnObjectsNameAttribute = "FileFacsimilePrinting";
		
	EndIf;
	
	If Not IsBlankString(AnObjectsNameAttribute)
		AND ValueIsFilled(Object[AnObjectsNameAttribute]) Then
		
		FileData = GetFileData(ThisForm.Object[AnObjectsNameAttribute], UUID);
		AttachedFilesClient.OpenFile(FileData);
		
	Else
		
		MessageText = NStr("en = 'Picture for viewing is absent'; ru = 'Отсутстует изображение для просмотра'");
		CommonUseClientServer.MessageToUser(MessageText,, "PictureURL");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddImageAtClient()
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en='To select the image it is necessary to record the object. Record?';ru='Для выбора изображения необходимо записать объект. Записать?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddImageAtClientEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddImageAtClientFragment();
	
EndProcedure

&AtClient
Procedure AddImageAtClientEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        
        Return;
        
    EndIf;
    
    Write();
    
    
    AddImageAtClientFragment();

EndProcedure

&AtClient
Procedure AddImageAtClientFragment()
    
    Var FileID, AnObjectsNameAttribute, Filter;
    
    If WorkWithLogo Then
        
        AnObjectsNameAttribute = "LogoFile";
        
    ElsIf WorkWithFacsimile Then
        
        AnObjectsNameAttribute = "FileFacsimilePrinting";
        
    EndIf;
    
    If ValueIsFilled(Object[AnObjectsNameAttribute]) Then
        
        SeeAttachedFile();
        
    ElsIf ValueIsFilled(Object.Ref) Then
        
        FileID = New UUID;
        
        Filter = NStr("en = 'All Images (*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf)|*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf"
        + "|All files(*.*)|*.*"
        + "|bmp format (*.bmp*;*.dib;*.rle)|*.bmp;*.dib;*.rle"
        + "|GIF format (*.gif*)|*.gif"
        + "|JPEG format (*.jpeg;*.jpg)|*.jpeg;*.jpg"
        + "|PNG format (*.png*)|*.png"
        + "|TIFF format (*.tif)|*.tif"
        + "|icon format (*.ico)|*.ico"
        + "|metafile format (*.wmf;*.emf)|*.wmf;*.emf'");
        
        AttachedFilesClient.AddFiles(Object.Ref, FileID, Filter);
        
    EndIf;

EndProcedure

&AtClient
Procedure ChoosePictureFromAttachedFiles()
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("FileOwner", Object.Ref);
	ChoiceParameters.Insert("ChoiceMode", True);
	ChoiceParameters.Insert("CloseOnChoice", True);
	
	OpenForm("CommonForm.AttachedFiles", ChoiceParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure AddLogoImageEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return
    EndIf;
    
    Write();
    
    
    AddLogoImageFragment();

EndProcedure

&AtClient
Procedure AddLogoImageFragment()
    
    Var FileID;
    
    PicturesFlagsManagement(True, False);
    
    FileID = New UUID;
    AttachedFilesClient.AddFiles(Object.Ref, FileID);

EndProcedure // AddImage()

&AtClient
Procedure AddFacsimileImageEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return
    EndIf;
    
    Write();
    
    
    AddFacsimileImageFragment();

EndProcedure

&AtClient
Procedure AddFacsimileImageFragment()
    
    Var FileID;
    
    PicturesFlagsManagement(False, True);
    
    FileID = New UUID;
    AttachedFilesClient.AddFiles(Object.Ref, FileID);

EndProcedure // AddFacsimileImage()

#EndRegion

#Region ContactInformationSB

&AtServer
Procedure AddContactInformationServer(AddingKind, SetShowInFormAlways = False) Export
	
	ContactInformationSB.AddContactInformation(ThisObject, AddingKind, SetShowInFormAlways);
	
EndProcedure

&AtClient
Procedure Attachable_ActionCIClick(Item)
	
	ContactInformationSBClient.ActionCIClick(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIOnChange(Item)
	
	ContactInformationSBClient.PresentationCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIStartChoice(Item, ChoiceData, StandardProcessing)
	
	ContactInformationSBClient.PresentationCIStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIClearing(Item, StandardProcessing)
	
	ContactInformationSBClient.PresentationCIClearing(ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_CommentCIOnChange(Item)
	
	ContactInformationSBClient.CommentCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationSBExecuteCommand(Command)
	
	ContactInformationSBClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region TitlesCollapsedDisplay

&AtClientAtServerNoContext
Procedure SetAllTitlesCollapsedDisplay(Form)
	
	SetTitleLegalData(Form);
	SetTitleBankAccount(Form);
	SetTitlePettyCash(Form);
	SetTitleContactInformation(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetTitleLegalData(Form)
	
	Object = Form.Object;
	DynamicParameters = New Array;
	
	If Not IsBlankString(Object.TIN) Then
		DynamicParameters.Add(NStr("ru='ИНН'; en = 'TIN'") + " " + Object.TIN);
	EndIf;
	
	If Not IsBlankString(Object.RegistrationNumber) Then
		DynamicParameters.Add(NStr("ru='ОГРН'; en = 'Reg. number'") + " " + Object.RegistrationNumber);
	EndIf;
	
	SetTitleCollapsedDisplay(Form, "LegalData", DynamicParameters);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetTitleBankAccount(Form)
	
	Object = Form.Object;
	DynamicParameters = New Array;
	
	If ValueIsFilled(Object.BankAccountByDefault) Then
		DynamicParameters.Add(Object.BankAccountByDefault);
	EndIf;
	
	SetTitleCollapsedDisplay(Form, "MainBankAccount", DynamicParameters);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetTitlePettyCash(Form)
	
	Object = Form.Object;
	DynamicParameters = New Array;
	
	If ValueIsFilled(Object.PettyCashByDefault) Then
		DynamicParameters.Add(Object.PettyCashByDefault);
	EndIf;
	
	SetTitleCollapsedDisplay(Form, "MainPettyCash", DynamicParameters);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetTitleContactInformation(Form)
	
	Object = Form.Object;
	DynamicParameters = New Array;
	
	LegalAddress = ContactInformationSBClientServer.GetContactInformationValue(Form, PredefinedValue("Catalog.ContactInformationKinds.CompanyLegalAddress"));
	If ValueIsFilled(LegalAddress) Then
		DynamicParameters.Add(LegalAddress);
	EndIf;
	
	Phone = ContactInformationSBClientServer.GetContactInformationValue(Form, PredefinedValue("Catalog.ContactInformationKinds.CompanyPhone"));
	If ValueIsFilled(Phone) Then
		DynamicParameters.Add(NStr("ru='тел.:'; en = 'tel.:'") + " " + Phone);
	EndIf;
	
	SetTitleCollapsedDisplay(Form, "ContactInformation", DynamicParameters);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetTitleCollapsedDisplay(Form, GroupName, DynamicParameters)
	
	TitleText = Form.Items[GroupName].Title;
	If DynamicParameters.Count() > 0 Then
		TitleText = TitleText + ": ";
		For Each Parameter In DynamicParameters Do
			TitleText = TitleText + Parameter + ", ";
		EndDo;
		StringFunctionsClientServer.DeleteLatestCharInRow(TitleText, 2);
	EndIf;
	
	Form.Items[GroupName].CollapsedRepresentationTitle = TitleText;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
	
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
	
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

// ServiceTechnology.InformationCenter
&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure

// End ServiceTechnology.InformationCenter

#EndRegion



