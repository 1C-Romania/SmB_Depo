////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// The function returns the file data
//
&AtServerNoContext
Function GetFileData(PictureFile, UUID)
	
	Return AttachedFiles.GetFileData(PictureFile, UUID);
	
EndFunction // GetFileData()

// Procedure sets received values to the form attributes
//
&AtClient
Procedure PicturesFlagsManegment(ThisIsWorkingWithLogo = False, ThisIsWorkingWithFacsimile = False)
	
	WorkWithLogo = ThisIsWorkingWithLogo;
	WorkWithFacsimile = ThisIsWorkingWithFacsimile;
	
EndProcedure // WorkWithImageFlagsManegment()

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
Procedure ReflectUpdateFormsProperty()
	
	//( elmi
	If Object.RegistrationCountry <>  PredefinedValue("Catalog.WorldCountries.Russia") Then
		Return;
	EndIf;
	//) elmi
	
	If Object.LegalEntityIndividual = LegalEntity Then
		
		If UpdateAvailable Then
		
			If Not IsBlankString(Object.TIN)
				AND StrLen(Object.TIN) > 10  Then
				
				Object.TIN = Left(Object.TIN, 10);
				
			EndIf;
			
			If ValueIsFilled(Object.Individual) Then
				
				Object.Individual = Undefined;
				
			EndIf;
			
		EndIf;
		
		Items.TIN.Mask = "9999999999"; 
		
		Items.PagesGroup.CurrentPage = Items.IndividualGroupUnavailable;
		Items.GroupTINKPP.CurrentPage = Items.PageCRRVisible;
		
	Else
		
		If UpdateAvailable 
			AND Not IsBlankString(Object.KPP) Then
			
			Object.KPP = "";
			
		EndIf;
		
		Items.TIN.Mask = "999999999999";
		
		Items.PagesGroup.CurrentPage = Items.GroupIndividualAvailable;
		Items.GroupTINKPP.CurrentPage = Items.HiddenKPPPage;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// Function returns the file URL
//
Function GetPictureCurrentVersion(PictureFile)
	
	Return PictureFile.CurrentVersion;
	
EndFunction // GetCurrentImageVersion()

&AtClient
// Procedure is responsible for displaying/updating the corresponding image
//
Procedure SetPictureToForm(ActiveAddress, ObjectAttribute)
	
	CurrentFile = GetPictureCurrentVersion(ObjectAttribute);
	ActiveAddress = ?(CurrentFile.IsEmpty(), "", FileOperationsServiceServerCall.GetURLForOpening(CurrentFile));
	
EndProcedure

// Image view procedure
//
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
		
		MessageText = NStr("en='Picture for viewing is absent';ru='Отсутстует изображение для просмотра'");
		CommonUseClientServer.MessageToUser(MessageText,, "PictureURL");
		
	EndIf;
	
EndProcedure // ViewAttachedFile()

// Procedure of the image adding for the products and services
//
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

EndProcedure // AddImageAtClient()

// The function returns the file (image) data
//
&AtServerNoContext
Function URLImages(PictureFile, FormID)
	
	SetPrivilegedMode(True);
	Return AttachedFiles.GetFileData(PictureFile, FormID).FileBinaryDataRef;
	
EndFunction // ImageURL()

// Procedure opens the list of the image selection from already attached files
//
&AtClient
Procedure ChoosePictureFromAttachedFiles()
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("FileOwner", Object.Ref);
	ChoiceParameters.Insert("ChoiceMode", True);
	ChoiceParameters.Insert("CloseOnChoice", True);
	
	OpenForm("CommonForm.AttachedFiles", ChoiceParameters, ThisForm);
	
EndProcedure // SelectImageFromAttachedFiles()

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	LegalEntity = Enums.LegalEntityIndividual.LegalEntity;
	
	AddressLogo 			= ?(Object.LogoFile.IsEmpty(), 			"", URLImages(Object.LogoFile, UUID));
	AddressFaxPrinting = ?(Object.FileFacsimilePrinting.IsEmpty(), "", URLImages(Object.FileFacsimilePrinting, UUID));
	
	// Filling the company calendar (only for new companies)
	If Not ValueIsFilled(Object.Ref) Then
		
		Object.BusinessCalendar = SmallBusinessServer.GetCalendarByProductionCalendaRF();
		
	EndIf;
	
	UpdateAvailable = AccessRight("Update", Metadata.Catalogs.Companies);
	
	FunctionalOptionAccountingByMultipleCompanies = Constants.FunctionalOptionAccountingByMultipleCompanies.Get();
	
	ReflectUpdateFormsProperty();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.InformationCenter
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	// End StandardSubsystems.InformationCenter
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnCreateAtServer(ThisForm, Object, "GroupContactInformation");
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.PrintCommands);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
EndProcedure // OnCreateAtServer()

&AtServer
// Event handler procedure OnReadAtServer
//
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.ContactInformation	
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

&AtClient
// Event handler procedure OnOpen.
// Sets the form attribute visible.
//
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not FunctionalOptionAccountingByMultipleCompanies Then
		MessageText = NStr("en='You can not add a new company as the ""Accounting for several companies"" check box is not selected in the accounting parameters settings!';ru='Нельзя добавить новую организацию, т.к. в настройках параметров учета не установлен признак ""Учет по нескольким организациям""!'");
		ShowMessageBox(Undefined,MessageText);
		Cancel = True;
	EndIf;
	
EndProcedure // OnOpen()

// SelectionProcessor form event handler procedure
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.AttachedFiles"
		AND ValueIsFilled(ValueSelected) Then
		
		If WorkWithLogo Then
			
			Object.LogoFile = ValueSelected;
			AddressLogo = URLImages(Object.LogoFile, UUID)
			
		ElsIf WorkWithFacsimile Then
			
			Object.FileFacsimilePrinting = ValueSelected;
			AddressFaxPrinting = URLImages(Object.FileFacsimilePrinting, UUID)
			
		EndIf;
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

&AtClient
// Procedure-handler of the NotificationProcessing event.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		
	EndIf;
	
	If EventName = "DefaultBankAccountChanged"
		AND TypeOf(Parameter) = Type("Structure") 
		AND Parameter.Property("BankAccountByDefault")
		AND ValueIsFilled(Parameter.BankAccountByDefault) Then
		
		Object.BankAccountByDefault	= Parameter.BankAccountByDefault;
		ThisForm.Modified			= True;
		
	ElsIf EventName = "DefaultBankAccountChanged" Then
			
			ThisForm.Read();
			
	ElsIf EventName = "Record_AttachedFile" Then
		
		Modified	= True;
		If WorkWithLogo Then
			
			Object.LogoFile = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
			AddressLogo = URLImages(Object.LogoFile, UUID);
			WorkWithLogo = False;
			
		ElsIf WorkWithFacsimile Then
			
			Object.FileFacsimilePrinting = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
			AddressFaxPrinting = URLImages(Object.FileFacsimilePrinting, UUID);
			WorkWithFacsimile = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.BeforeWriteAtServer(ThisForm, CurrentObject, Cancel);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // BeforeWriteAtServer()

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.FillCheckProcessingAtServer(ThisForm, Object, Cancel);
	// End StandardSubsystems.ContactInformation	
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// OnChange event handler procedure of the Description input field.
//
Procedure DescriptionOnChange(Item)
	
	If Not ValueIsFilled(Object.DescriptionFull) Then
		Object.DescriptionFull = Object.Description;
	EndIf;
	
	If Not ValueIsFilled(Object.PayerDescriptionOnTaxTransfer) Then
		Object.PayerDescriptionOnTaxTransfer = Object.Description;
	EndIf;
	
EndProcedure // DescriptionOnChange()

&AtClient
// Event handler procedure OnChange of input field LegalEntityIndividual.
//
Procedure LegalEntityIndividualOnChange(Item)
	
	ReflectUpdateFormsProperty();
	
EndProcedure // LegalEntityIndividualOnChange()

&AtClient
// Procedure - SelectionBegin event handler of the BankAccountByDefault field.
//
Procedure BankAccountByDefaultStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		StandardProcessing = False;
		Message = New UserMessage();
		Message.Text = NStr("en='Catalog item is not recorded yet';ru='Элемент справочника еще не записан.'");
		Message.Message();
		
	EndIf;
	
EndProcedure // BankAccountByDefaultStartChoice()

&AtClient
// Procedure - OnChange event handler of the ImageFile field.
//
Procedure PictureFileOnChange(Item)
	
	SetPictureToForm(AddressLogo, Object.LogoFile);
	
EndProcedure // ImageFileOnChange()

&AtClient
// Procedure - OnChange event handler of the FileFacsimilePrinting field.
//
Procedure FilePrintToFaxOnChange(Item)
	
	SetPictureToForm(AddressFaxPrinting, Object.FileFacsimilePrinting);
	
EndProcedure //FacsimilePrintingFileOnChange()

&AtClient
// Procedure - Click event handler of LogoAddress decoration
//
Procedure AddressLogoClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	PicturesFlagsManegment(True, False);
	AddImageAtClient();
	
EndProcedure //LogoAddressClick()

&AtClient
// Procedure - Click event handler of the FacsimilePrintingAddress decoration
//
Procedure AddressFaxPrintingClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	PicturesFlagsManegment(False, True);
	AddImageAtClient();
	
EndProcedure //FacsimilePrintingAddressClick()

&AtClient
// Procedure - Click event handler of the ShowLogoImportingHelp decoration
Procedure ShowHelpBootLogoClick(Item)
	
	OpenParameters = New Structure("Title, ToolTipKey", 
		"How to load our logo?",
		"Companies_ShowHelpBootLogo");
	
	OpenForm("DataProcessor.ToolTipManager.Form", OpenParameters);
	
EndProcedure //ShowLogoImportingHelpClick()

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

// Procedure - AddLogoImage command handler
//
&AtClient
Procedure AddImageLogo(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en='To select the image it is necessary to record the object. Record?';ru='Для выбора изображения необходимо записать объект. Записать?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddLogoImageEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddLogoImageFragment();
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
    
    PicturesFlagsManegment(True, False);
    
    FileID = New UUID;
    AttachedFilesClient.AddFiles(Object.Ref, FileID);

EndProcedure // AddImage()

// Procedure - ChangeLogoImage command handler
//
&AtClient
Procedure ChangeImageLogo(Command)
	
	ClearMessages();
	
	If ValueIsFilled(Object.LogoFile) Then
		
		AttachedFilesClient.OpenAttachedFileForm(Object.LogoFile);
		
	Else
		
		MessageText = NStr("en='Picture for editing is absent';ru='Отсутстует изображение для редактирования'");
		CommonUseClientServer.MessageToUser(MessageText,, "AddressLogo");
		
	EndIf;
	
EndProcedure // ChangeImage()

// Procedure - ClearLogoImage command handler
//
&AtClient
Procedure ClearImageLogo(Command)
	
	Object.LogoFile = Undefined;
	AddressLogo = "";
	
EndProcedure // ClearLogoImage()

// Procedure - ClearImage command handler
//
&AtClient
Procedure ViewImageLogo(Command)
	
	PicturesFlagsManegment(True, False);
	SeeAttachedFile();
	
EndProcedure // ViewImage()

// Procedure - SelectImageFromAttachedFiles command handler
&AtClient
Procedure LogoOfAttachedFiles(Command)
	
	PicturesFlagsManegment(True, False);
	ChoosePictureFromAttachedFiles();
	
EndProcedure // SelectImageFromAttachedFiles()

// Procedure - AddFacsimileImage command handler
//
&AtClient
Procedure AddImageFacsimile(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en='To select the image it is necessary to record the object. Record?';ru='Для выбора изображения необходимо записать объект. Записать?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddFacsimileImageEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddFacsimileImageFragment();
EndProcedure

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
    
    PicturesFlagsManegment(False, True);
    
    FileID = New UUID;
    AttachedFilesClient.AddFiles(Object.Ref, FileID);

EndProcedure // AddFacsimileImage()

// Procedure - ChangeFacsimileImage command handler
//
&AtClient
Procedure ChangeImageFacsimile(Command)
	
	ClearMessages();
	
	If ValueIsFilled(Object.FileFacsimilePrinting) Then
		
		AttachedFilesClient.OpenAttachedFileForm(Object.FileFacsimilePrinting);
		
	Else
		
		MessageText = NStr("en='Picture for editing is absent';ru='Отсутстует изображение для редактирования'");
		CommonUseClientServer.MessageToUser(MessageText,, "AddressLogo");
		
	EndIf;
	
EndProcedure // ChangeFacsimileImage()

// Procedure - ClearFacsimileImage command handler
//
&AtClient
Procedure ClearImageFacsimile(Command)
	
	Object.FileFacsimilePrinting = Undefined;
	AddressFaxPrinting = "";
	
EndProcedure // ClearImageFacsimile()

// Procedure - ViewFacsimileImage command handler
//
&AtClient
Procedure ViewPictureFacsimile(Command)
	
	PicturesFlagsManegment(False, True);
	SeeAttachedFile();
	
EndProcedure // ViewImageFacsimile()

// Procedure - ViewFacsimileImage command handler
//
&AtClient
Procedure FacsimileOfAttachedFiles(Command)
	
	PicturesFlagsManegment(False, True);
	ChoosePictureFromAttachedFiles();
	
EndProcedure // FacsimileFromAttachedFiles()

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

// StandardSubsystems.ContactInformation
&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	
	ContactInformationManagementClient.PresentationOnChange(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	Result = ContactInformationManagementClient.PresentationStartChoice(ThisForm, Item, , StandardProcessing);
	
	RefreshContactInformation(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	
	Result = ContactInformationManagementClient.ClearingPresentation(ThisForm, Item.Name);
	
	RefreshContactInformation(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	
	Result = ContactInformationManagementClient.LinkCommand(ThisForm, Command.Name);
	
	RefreshContactInformation(Result);
	
	ContactInformationManagementClient.OpenAddressEntryForm(ThisForm, Result);
	
EndProcedure

&AtServer
Function RefreshContactInformation(Result = Undefined)
	
	Return ContactInformationManagement.RefreshContactInformation(ThisForm, Object, Result);
	
EndFunction
// End StandardSubsystems.ContactInformation

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	
	If Command.Name = "PreviewPrintedFormsInvoiceForPayment1" Then
		
		Command = ThisForm.Commands.PrintCommandsPopupPrintPrintCommand1;
		
	ElsIf Command.Name = "PrintFaxPrintWorkAssistant0" Then
		
		Command = ThisForm.Commands.PrintCommandsPopupPrintPrintCommand0;
		
	EndIf;
	
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
