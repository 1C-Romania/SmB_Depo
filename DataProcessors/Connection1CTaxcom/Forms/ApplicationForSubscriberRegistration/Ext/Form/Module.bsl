
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	// Create structure with the processor attributes.
	
	Items.LoginLabel.Title = NStr("en = 'Login:'") + " " + Parameters.login;
	
	FormStatus      = Parameters.statusApplicationFormED;
	RequestNumber      = Parameters.numberRequestED;
	RowRequestDate = Parameters.dateRequestED;
	RequestStatus     = Parameters.requestStatusED;
	
	If Not IsBlankString(RowRequestDate) Then
		Try
			RequestDate = Date(StrReplace(StrReplace(StrReplace(RowRequestDate, "-", "")," ",""), ":",""));
		Except
			RequestDate = Date(1,1,1);
		EndTry;
	Else
		RequestDate = Date(1,1,1);
	EndIf;
	
	If FormStatus = "new" OR Not ValueIsFilled(FormStatus) Then
		
		Items.FormHeaderLabel.Title = NStr("en = 'ED exchange participant application for registration'");
		Items.RequestStatusLabel.Title = NStr("en = 'New application'");
		Items.SendApplication.Visible = True;
		
		Items.ApplicationForRegistrationPages.CurrentPage = Items.ApplicationForRegistrationPage;
		
	ElsIf FormStatus = "change" Then
		
		Items.FormHeaderLabel.Title = NStr("en = 'Change data of ED exchange participant'");
		Items.RequestStatusLabel.Title = NStr("en = 'New application'");
		Items.SendApplication.Visible = True;
		
		Items.ApplicationForRegistrationPages.CurrentPage = Items.ApplicationForChangePage;
		
	ElsIf FormStatus = "show" Then
		
		HeaderText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Application No%1 from %2'"),
			RequestNumber,
			Format(RequestDate, "DF = mm dd yyyy y.  HH:mm:ss"));
		
		Items.FormHeaderLabel.Title = HeaderText;
		
		Items.SendApplication.Visible = False;
		Items.Close.DefaultButton = True;
		
		DSCertificate = Parameters.nameDSCertificate;
		
		If Not ValueIsFilled(DSCertificate) Then
			Items.DSCertificate.Visible = False;
		EndIf;
		
		Items.DSCertificate.ChoiceButton = False;
		Items.ApplicationForRegistrationPages.CurrentPage = Items.ApplicationForChangePage;
		ReadOnly = True;
		
	EndIf;
	
	If Not ValueIsFilled(RequestStatus) OR RequestStatus = "none" Then
		
		TextStatus = NStr("en='New application.'");
		Items.CauseLabel.Visible = False;
		
	ElsIf RequestStatus = "notconsidered" Then
		
		TextStatus = NStr("en='Operator has not yet reviewed your application.'");
		Items.CauseLabel.Visible = False;
		
	ElsIf RequestStatus = "rejected" Then
		
		TextStatus = NStr("en='Operator rejected application.'");
		Items.CauseLabel.Visible = True;
		
	Else
		
		// RequestStatus = obtained
		TextStatus = NStr("en='Application is successfully executed by operator'");
		Items.CauseLabel.Visible = False;
		
	EndIf;
	
	Items.RequestStatusLabel.Title = TextStatus;
	
	// Update information about company
	UpdateCompanyInformation();
	
	If ReadOnly Then
		Items.Address.ChoiceButton   = False;
		Items.Address.OpenButton = True;
	Else
		Items.Address.ChoiceButton   = True;
		Items.Address.OpenButton = False;
	EndIf;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.CommentGroup.Representation = UsualGroupRepresentation.None;
		Items.CompanyInformationGroup.Representation = UsualGroupRepresentation.WeakSeparation;
		Items.ContactInformationGroup.Representation = UsualGroupRepresentation.WeakSeparation;
		Items.CompanyHeadInformationGroup.Representation = UsualGroupRepresentation.WeakSeparation;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not SoftwareClosing Then
		
		If ThisObject.Modified Then
			
			Cancel = True;
			NotifyDescription = New NotifyDescription("OnAnswerQuestionAboutClosingModifiedForm",
				ThisObject);
			
			QuestionText = NStr("en = 'Data was changed. Close form without saving data?'");
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			Return;
			
		EndIf;
		
		If FormStatus <> "show" AND Not SendButtonIsPressed Then
			
			QueryParameters = New Array;
			QueryParameters.Add(New Structure("Name, Value", "endForm", "close"));
			// Shows that the Close button is clicked
			
			// Send parameters to server
			OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext,
				ThisObject,
				QueryParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure StartAddressSelection(Item, ChoiceData, StandardProcessing)
	
	// Prepare data and open form for entering address
	StandardProcessing = False;
	SelectAddress(False);
	
EndProcedure

&AtClient
Procedure AddressOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	SelectAddress(True);
	
EndProcedure

&AtClient
Procedure LabelCauseClick(Item)
	
	Connection1CTaxcomClient.ShowEDFApplicationRejection(InteractionContext);
	
EndProcedure

&AtClient
Procedure LabelLogoutClick(Item)
	
	OnlineUserSupportClient.HandleUserExit(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure LegalEntityIndividualOnChange(Item)
	
	SettingsByLegalEntityIndividual();
	
EndProcedure

&AtClient
Procedure DecorationTechnicalSupportNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
	If URL = "TechSupport" Then
		StandardProcessing = False;
		OnlineUserSupportClient.OpenDialogForSendingEmail(
			InteractionContext,
			MessageParametersToTechicalSupport());
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SendApplication(Command)
	
	// Check if required fields are filled in
	Error = False;
	
	If IsBlankString(Company) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en ='The Company field is not filled in'");
		Message.Field = "Company";
		Message.Message();
	EndIf;
	
	If IsBlankString(Address) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en ='The Address field is not filled in'");
		Message.Field = "Address";
		Message.Message();
	EndIf;
	
	If IsBlankString(Phone) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en ='The Phone field is not filled in'");
		Message.Field = "Phone";
		Message.Message();
	EndIf;
	
	// Check address
	
	If IsBlankString(StateCode) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text =
			NStr("en ='State code is not specified (State code should be specified in the Address of the ED exchange participant form)'");
		Message.Field = "Address";
		Message.Message();
	EndIf;
	
	If IsBlankString(TIN) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en ='The TIN field is not filled in'");
		Message.Field = "TIN";
		Message.Message();
	EndIf;
	
	If LegalEntityIndividual <> "LegalEntity" AND LegalEntityIndividual <> "Ind" Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en ='Company type (legal entity or individual) is not selected'");
		Message.Field = "LegalEntityIndividual";
		Message.Message();
	EndIf;
	
	If IsBlankString(KPP) AND LegalEntityIndividual = "LegalEntity" Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en ='The KPP field is not filled in'");
		Message.Field = "KPP";
		Message.Message();
	EndIf;
	
	If IsBlankString(OGRN) AND LegalEntityIndividual = "LegalEntity" Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en ='The OGRN field is not filled in'");
		Message.Field = "OGRN";
		Message.Message();
	EndIf;
	
	If IsBlankString(TaxAuthorityCode) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en ='The Tax authority code field is not filled in'");
		Message.Field = "TaxAuthorityCode";
		Message.Message();
	EndIf;
	
	If IsBlankString(Surname) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en ='The Surname field is not filled in'");
		Message.Field = "Surname";
		Message.Message();
	EndIf;
	
	If IsBlankString(Name) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en ='The Name field is not filled in'");
		Message.Field = "Name";
		Message.Message();
	EndIf;
	
	// Additional checks
	
	If Not IsBlankString(Phone) Then
		If StrLen(Phone) > 20 Then
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en ='Phone should contain 20 or fewer characters.'");
			Message.Field = "Phone";
			Message.Message();
		EndIf;
	EndIf;
	
	If Not IsBlankString(StateCode) Then
		Try
			StateCodeNumber = Number(TrimAll(StateCode));
			If StrLen(TrimAll(StateCode)) <> 2 Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en ='State code should contain 2 digits'");
				Message.Field = "Address";
				Message.Message();
			Else
				If StateCodeNumber > 99 OR StateCodeNumber < 1 Then
					Error    = True;
					Message = New UserMessage;
					Message.Text = NStr("en ='State code should be from 01 to 99'");
					Message.Field = "StateCode";
					Message.Message();
				EndIf;
			EndIf;
		Except
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en ='Invalid characters are used in the State code'");
			Message.Field = "Address";
			Message.Message();
		EndTry;
	EndIf;
	
	If Not IsBlankString(TIN) Then
		Try
			TINNumber = Number(TrimAll(TIN));
			If StrLen(TrimAll(TIN)) <> 12 AND LegalEntityIndividual = "Ind" Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en ='TIN should contain 12 digits'");
				Message.Field = "TIN";
				Message.Message();
			ElsIf StrLen(TrimAll(TIN)) <> 10 AND LegalEntityIndividual = "LegalEntity" Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en ='TIN should contain 10 digits'");
				Message.Field = "TIN";
				Message.Message();
			EndIf;
		Except
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en ='Invalid characters are used in TIN'");
			Message.Field = "TIN";
			Message.Message();
		EndTry;
	EndIf;
	
	If Not IsBlankString(KPP) Then
		Try
			KPPNumber = Number(TrimAll(KPP));
			If StrLen(TrimAll(KPP)) <> 9 Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en ='KPP should contain 9 digits'");
				Message.Field = "KPP";
				Message.Message();
			EndIf;
		Except
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en ='Invalid characters are used in KPP'");
			Message.Field = "KPP";
			Message.Message();
		EndTry;
	EndIf;
	
	If Not IsBlankString(OGRN) Then
		Try
			OGRNNumber = Number(TrimAll(OGRN));
			If StrLen(TrimAll(OGRN)) <> 13  AND LegalEntityIndividual = "LegalEntity" Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en ='OGRN should contain 13 digits'");
				Message.Field = "OGRN";
				Message.Message();
			ElsIf StrLen(TrimAll(OGRN)) <> 15  AND LegalEntityIndividual = "Ind" Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en ='OGRN should contain 15 digits'");
				Message.Field = "OGRN";
				Message.Message();
			EndIf;
		Except
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en ='Invalid characters are used in OGRN'");
			Message.Field = "OGRN";
			Message.Message();
		EndTry;
	EndIf;
	
	If Not IsBlankString(TaxAuthorityCode) Then
		Try
			TaxAuthorityNumberCode = Number(TrimAll(TaxAuthorityCode));
			If StrLen(TrimAll(TaxAuthorityCode)) <> 4 Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en ='Tax authority code should contain 4 digits'");
				Message.Field = "TaxAuthorityCode";
				Message.Message();
			EndIf;
		Except
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en ='Invalid characters are used in the Tax authority code'");
			Message.Field = "TaxAuthorityCode";
			Message.Message();
		EndTry;
	EndIf;
	
	If Error Then
		Return;
	EndIf;
	
	// Pass data to server
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "endForm"           , "send"));
	// Shows that the Send button is clicked
	
	QueryParameters.Add(New Structure("Name, Value", "postindexED"       , IndexOf));
	QueryParameters.Add(New Structure("Name, Value", "addressregionED"   , Region));
	QueryParameters.Add(New Structure("Name, Value", "codregionED"       , StateCode));
	QueryParameters.Add(New Structure("Name, Value", "addresstownshipED" , District));
	QueryParameters.Add(New Structure("Name, Value", "addresscityED"     , City));
	QueryParameters.Add(New Structure("Name, Value", "addresslocalityED" , Settlement));
	QueryParameters.Add(New Structure("Name, Value", "addressstreetED"   , Street));
	QueryParameters.Add(New Structure("Name, Value", "addressbuildingED" , Building));
	QueryParameters.Add(New Structure("Name, Value", "addresshousingED"  , Section));
	QueryParameters.Add(New Structure("Name, Value", "addressapartmentED", Apartment));
	QueryParameters.Add(New Structure("Name, Value", "addressphoneED"    , Phone));
	QueryParameters.Add(New Structure("Name, Value", "agencyED"          , Company));
	QueryParameters.Add(New Structure("Name, Value", "tinED"             , TIN));
	QueryParameters.Add(New Structure("Name, Value", "kppED"             , KPP));
	QueryParameters.Add(New Structure("Name, Value", "ogrnED"            , OGRN));
	QueryParameters.Add(New Structure("Name, Value", "codeimnsED"        , TaxAuthorityCode));
	QueryParameters.Add(New Structure("Name, Value", "lastnameED"        , Surname));
	QueryParameters.Add(New Structure("Name, Value", "firstnameED"       , Name));
	QueryParameters.Add(New Structure("Name, Value", "middlenameED"      , Patronymic));
	QueryParameters.Add(New Structure("Name, Value", "identifierTaxcomED", CompanyID));
	QueryParameters.Add(New Structure("Name, Value", "orgindED"          , LegalEntityIndividual));
	QueryParameters.Add(New Structure("Name, Value", "addressED"         , Address));
	
	If FormStatus <> "show" Then
		
		If ValueIsFilled(DSCertificate) Then
			
			PreviousCertificate = OnlineUserSupportClientServer.SessionParameterValue(
				InteractionContext.COPContext,
				"IDDSCertificate");
			
			CertificatePresentation = "";
			CertificateBinaryData = CertificateBinaryData(DSCertificate, CertificatePresentation);
			
			If DSCertificate <> PreviousCertificate Then
				
				OnlineUserSupportClientServer.WriteContextParameter(
					InteractionContext.COPContext,
					"IDDSCertificate_Dop",
					DSCertificate);
				
			EndIf;
			
			QueryParameters.Add(New Structure("Name, Value", "nameDSCertificate", CertificatePresentation));
			
			If CertificateBinaryData <> Undefined Then
				
				StringBase64 = Base64String(CertificateBinaryData);
				QueryParameters.Add(New Structure("Name, Value", "certificateED", StringBase64));
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ThisObject.Modified = False;
	SendButtonIsPressed = True;
	
	// Send parameters to server
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(
		InteractionContext,
		ThisObject,
		QueryParameters);
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure that receives information
// about company from the configuration by company data
&AtServer
Procedure UpdateCompanyInformation()
	
	LegalEntityIndividual                = Parameters.orgindED;
	IndexOf                   = Parameters.postindexED;
	Region                   = Parameters.addressregionED;
	StateCode               = Parameters.coderegionED;
	District                    = Parameters.addresstownshipED;
	City                    = Parameters.addresscityED;
	Settlement          = Parameters.addresslocalityED;
	Street                    = Parameters.addressstreetED;
	Building                      = Parameters.addressbuildingED;
	Section                   = Parameters.addresshousingED;
	Apartment                 = Parameters.addressapartmentED;
	Phone                  = Parameters.addressphoneED;
	Company              = Parameters.agencyED;
	TIN                      = Parameters.tinED;
	KPP                      = Parameters.kppED;
	OGRN                     = Parameters.ogrnED;
	TaxAuthorityCode      = Parameters.codeimnsED;
	Surname                  = Parameters.lastnameED;
	Name                      = Parameters.firstnameED;
	Patronymic                 = Parameters.middlenameED;
	CompanyID = Parameters.identifierTaxcomED;
	
	If FormStatus <> "show" Then
		DSCertificate = Parameters.IDDSCertificate;
	EndIf;
	
	GenerateAddress();
	
	LegalEntityIndividual = ?(IsBlankString(LegalEntityIndividual), "LegalEntity", LegalEntityIndividual);
	
	SettingsByLegalEntityIndividual();
	
EndProcedure

// Procedure of setting
// the form items depending on the LegalEntityIndividual switcher
&AtServer
Procedure SettingsByLegalEntityIndividual()
	
	If LegalEntityIndividual = "LegalEntity" Then
		Items.KPP.Enabled = True;
		Items.KPP.AutoMarkIncomplete = True;
		Items.OGRN.AutoMarkIncomplete = True;
	Else
		Items.KPP.Enabled = False;
		Items.KPP.AutoMarkIncomplete  = False;
		Items.OGRN.AutoMarkIncomplete = False;
		KPP = "";
	EndIf;
	
EndProcedure

// Generates address row by address attributes
&AtServer
Procedure GenerateAddress() Export
	
	Addr = "";
	
	AddSubstring(Addr, IndexOf);
	AddSubstring(Addr, Region);
	AddSubstring(Addr, StateCode, "Region ");
	AddSubstring(Addr, District);
	AddSubstring(Addr, City);
	AddSubstring(Addr, Settlement);
	AddSubstring(Addr, Street);
	AddSubstring(Addr, Building     , "h. ");
	AddSubstring(Addr, Section  , "build. ");
	AddSubstring(Addr, Apartment, "appartment ");
	
	Address = Addr;
	
EndProcedure

// Procedure of adding a
// subrow to the Parameters row:
// - SourceRow - String - source row;
// - Subrow      - String - String that should be added to the end of a source row;
// - Prefix        - String - String that is added before the subrow;
// - Separator    - String - String that serves as a separator between a row and a subrow
//
&AtServer
Procedure AddSubstring(SourceLine, Val Substring, Prefix = "", Delimiter = ", ")
	
	If Not IsBlankString(SourceLine) AND Not IsBlankString(Substring) Then
		SourceLine = SourceLine + Delimiter;
	EndIf;
	
	If Not IsBlankString(Substring) Then
		SourceLine = SourceLine + Prefix + Substring;
	EndIf;
	
EndProcedure

// Receives binary data of a certificate by calling
// a corresponding function of the server predefined module.
//
// Parameters:
// - CertificateRef (AnyRef) - ref to data object containing certificate data
//
// Return value: BinaryData - if it was impossible to
// 					  receive certificate binary data, Undefined - otherwise.
//
&AtServerNoContext
Function CertificateBinaryData(Val CertificatRef, CertificatePresentation)
	
	CertificatePresentation = String(CertificatRef);
	CertificateBinaryData = Connection1CTaxcom.CertificateBinaryData(CertificatRef);
	
	Return CertificateBinaryData;
	
EndFunction

// Opens an address selection form in the
// modal mode and returns address attributes in the form of structure with the corresponding fields
//
// Parameters:
// - ViewOnly (Boolean): True - open form of selecting address for view only
//
// Return value: Structure with fields - address attributes;
// 					  Undefined if the OK button was not clicked in the address form during closing
// 
&AtClient
Procedure SelectAddress(ViewOnly = False)
	
	FormParameters = New Structure("ReadOnly", ViewOnly);
	
	If ViewOnly Then
		ClosingAlert = Undefined;
	Else
		ClosingAlert = New NotifyDescription("OnSelectAddress", ThisObject);
	EndIf;
	
	FormParameters.Insert("IndexOf"    , IndexOf);
	FormParameters.Insert("Region"    , Region);
	FormParameters.Insert("District"     , District);
	FormParameters.Insert("City"     , City);
	FormParameters.Insert("Settlement"  , Settlement);
	FormParameters.Insert("Street"     , Street);
	FormParameters.Insert("Building"       , Building);
	FormParameters.Insert("Section"    , Section);
	FormParameters.Insert("Apartment"  , Apartment);
	FormParameters.Insert("StateCode", StateCode);
	
	AddressOutputForm = OpenForm("DataProcessor.Connection1CTaxcom.Form.EDExchangeParticipantAddress",
		FormParameters,
		,
		,
		,
		,
		ClosingAlert);
	
	AddressOutputForm.InteractionContext = InteractionContext;
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, AddressOutputForm);
	
EndProcedure

&AtClient
Procedure OnSelectAddress(AddressParameters, AdditParameters) Export
	
	If TypeOf(AddressParameters) <> Type("Structure") Then
		Return;
	EndIf;
	
	// Set modification by passed data
	If Not ThisObject.Modified Then
		If    IndexOf          <> AddressParameters.IndexOf
			OR Region          <> AddressParameters.Region
			OR District           <> AddressParameters.District
			OR City           <> AddressParameters.City
			OR Settlement <> AddressParameters.Settlement
			OR Street           <> AddressParameters.Street
			OR Building             <> AddressParameters.Building
			OR Section          <> AddressParameters.Section
			OR Apartment        <> AddressParameters.Apartment
			OR StateCode      <> AddressParameters.StateCode Then
			
			ThisObject.Modified = True;
		EndIf;
	EndIf;
	
	// If address is changed, then changes
	IndexOf          = AddressParameters.IndexOf;
	Region          = AddressParameters.Region;
	District           = AddressParameters.District;
	City           = AddressParameters.City;
	Settlement = AddressParameters.Settlement;
	Street           = AddressParameters.Street;
	Building             = AddressParameters.Building;
	Section          = AddressParameters.Section;
	Apartment        = AddressParameters.Apartment;
	StateCode      = AddressParameters.StateCode;
	
	GenerateAddress();
	
EndProcedure

&AtClient
Procedure OnAnswerQuestionAboutClosingModifiedForm(QuestionResult, AdditParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject", NStr("en = '1C-Taxcom. ED exchange participant application for registration'"));
	Result.Insert("Whom", "1c-taxcom@1c.ru");
	
	MessageText = NStr("en = 'Dear sir or madam, %1. Would you help me to solve the problem.? Login: %2. %3 %TechnicalParameters% ----------------------------------------------- Sincerely, .'");
	
	If FormStatus = "new" OR IsBlankString(FormStatus) Then
		WhatFailed = NStr("en = 'I can not send an application for registration of ED exchange participant'");
	ElsIf FormStatus = "change" Then
		WhatFailed = NStr("en = 'I can not send an application for changing the data of ED exchange participant'");
	ElsIf FormStatus = "show" Then
		WhatFailed = NStr("en = 'I have some problems with an application of ED exchange participant'");
	EndIf;
	
	UserLogin = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"login");
	
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
		MessageText,
		WhatFailed,
		UserLogin,
		Connection1CTaxcomClient.TechnicalEDFParametersText(InteractionContext, DSCertificate));
	
	Result.Insert("MessageText", MessageText);
	Result.Insert("ConditionalRecipientName",
		InteractionContext.COPContext.MainParameters.LaunchLocation);
	
	Return Result;
	
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
