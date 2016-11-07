
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	EDFSetup = "";
	If Parameters.Property("EDFSetup", EDFSetup) AND ValueIsFilled(EDFSetup) Then
		EDFSettingsParameters = CommonUse.ObjectAttributesValues(EDFSetup,
			"Company, Counterparty, ConnectionStatus,
			|InvitationText, EmailForInvitation, OutgoingDocuments");
			
		OutgoingDocuments = EDFSettingsParameters.OutgoingDocuments.Unload();
		
		Filter = New Structure;
		Filter.Insert("EDExchangeMethod", Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom);
		FoundStrings = OutgoingDocuments.FindRows(Filter);
		
		// For outgoing and incoming invitations fields are filled differently.
		ConnectionStatus  = EDFSettingsParameters.ConnectionStatus;
		If ConnectionStatus = Enums.EDExchangeMemberStatuses.InvitationRequired
			OR ConnectionStatus = Enums.EDExchangeMemberStatuses.Disconnected
			OR ConnectionStatus = Enums.EDExchangeMemberStatuses.Error
			OR ConnectionStatus = Enums.EDExchangeMemberStatuses.AgreementExpectation Then
			
			Sender      = EDFSettingsParameters.Company;
			Recipient       = EDFSettingsParameters.Counterparty;
			If Not ValueIsFilled(EDFSettingsParameters.EmailForInvitation) Then
				Email = ElectronicDocumentsOverridable.CounterpartyEMailAddress(
					EDFSettingsParameters.Counterparty);
			Else
				Email = EDFSettingsParameters.EmailForInvitation;
			EndIf;
			
		ElsIf ConnectionStatus = Enums.EDExchangeMemberStatuses.ApprovalRequired
			OR ConnectionStatus = Enums.EDExchangeMemberStatuses.Connected Then
			Sender              = EDFSettingsParameters.Counterparty;
			Recipient               = EDFSettingsParameters.Company;
			CounterpartyID = FoundStrings[0].CounterpartyID;
		EndIf;
		
		If Not ValueIsFilled(EDFSettingsParameters.InvitationText) Then
			InvitationText = CommonUse.ObjectAttributeValue(FoundStrings[0].EDFProfileSettings,
				"InvitationsTextTemplate");
		Else
			InvitationText = EDFSettingsParameters.InvitationText;
		EndIf;
		EDFProfileSettings   = FoundStrings[0].EDFProfileSettings;
		
		Parameters.Property("FormIsOpenableFromEDFSetup", FormIsOpenableFromEDFSetup);
		Parameters.Property("Accept",                    Accept);
		Parameters.Property("Reject",                  Reject);
		
		EDFSettingTemplate = NStr("en='EDF setting with counterparty %1';ru='Настройка ЭДО с контрагентом %1'");
		EDFSettingText  = StringFunctionsClientServer.PlaceParametersIntoString(EDFSettingTemplate,
			EDFSettingsParameters.Counterparty);
		Items.DecorationEDFSetup.Title = EDFSettingText;
		
	EndIf;
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	
	If Form.FormIsOpenableFromEDFSetup Then
		Items.DecorationEDFSetup.Visible = False;
	EndIf;
	
	If Form.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.InvitationRequired")
		OR Form.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.Error")
		OR Form.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.Disconnected") Then
		Items.ID.Visible = False;
		Items.ButtonGroupApprovalRequired.Visible = False;
		
	ElsIf Form.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.AgreementExpectation") Then
		
		Items.ID.Visible = False;
		Items.ButtonGroupApprovalRequired.Visible   = False;
		Items.ButtonGroupInvitationRequired.Visible = False;
		Items.InvitationText.Enabled = False;
		Items.Email.Enabled = False;
		Items.ButtonCancel.DefaultButton = True;
		
	ElsIf Form.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.ApprovalRequired")
		OR Form.ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.Connected") Then
		
		Items.Email.Visible = False;
		Items.InvitationText.Visible = False;
		Items.ButtonGroupInvitationRequired.Visible = False;
		
		Items.AcceptButton.DefaultButton = True;
		If Form.Accept Then
			Items.RejectButton.Visible       = False;
		EndIf;
		If Form.Reject Then
			Items.AcceptButton.Visible           = False;
			Items.RejectButton.DefaultButton = True;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure DecorationEDFSetupClick(Item)
	
	FormParameters = New Structure;
	FormParameters.Insert("Key",           EDFSetup);
	FormParameters.Insert("ReadOnly", True);
	OpenForm("Catalog.EDUsageAgreements.Form.ItemForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure InvitationTextStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Notification = New NotifyDescription("EndInvitationTextEditing", ThisObject);
	FormTitle = NStr("en='Text for counterparty invitation';ru='Текст для приглашения контрагента'");
	CommonUseClient.ShowMultilineTextEditingForm(
		Notification, Items.InvitationText.EditText, FormTitle);
	
EndProcedure

#EndRegion

#Region CommandsActionsForms

&AtClient
Procedure SendInvitation(Command)
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	NotificationHandler = New NotifyDescription("SendInvitationNotification", ThisObject);
	FillMarker(NotificationHandler);
	
EndProcedure

&AtClient
Procedure AcceptInvitation(Command)
	
	ClearMessages();
	
	NotificationHandler = New NotifyDescription("AcceptInvitationNotification", ThisObject);
	FillMarker(NotificationHandler);
	
EndProcedure

&AtClient
Procedure RejectInvitation(Command)
	
	ClearMessages();
	
	NotificationHandler = New NotifyDescription("RejectInvitationNotification", ThisObject);
	FillMarker(NotificationHandler);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

&AtServer
Procedure UpdateEDFSettings(EDFSetup)
	
	SearchEDFSetup = EDFSetup.GetObject();
	SearchEDFSetup.EmailForInvitation = Email;
	SearchEDFSetup.InvitationText               = InvitationText;
	SearchEDFSetup.ConnectionStatus              = ConnectionStatus;
	SearchEDFSetup.AgreementState            = AgreementState;
	SearchEDFSetup.ErrorDescription                 = "";
	SearchEDFSetup.Write();
	
EndProcedure

&AtServer
Function AcceptRejectContactViaOperatorEDOAtServer(ID, InvitationAccepted, Marker)
	
	Result = False;
	
	SearchEDFSetup = EDFSetup.GetObject();
	If SearchEDFSetup.EDFSettingUnique() Then
		Result = ElectronicDocumentsInternal.AcceptRejectContactThroughEDFOperator(ID, InvitationAccepted, Marker);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SendInvitationsServer(PostedInvitations, Marker)
	
	// Table with counterparties attributes is being prepared.
	InvitationsTable = New ValueTable;
	InvitationsTable.Columns.Add("EDFProfileSettings");
	InvitationsTable.Columns.Add("EDFSetup");
	InvitationsTable.Columns.Add("Recipient");
	InvitationsTable.Columns.Add("Description");
	InvitationsTable.Columns.Add("DescriptionForUserMessage");
	InvitationsTable.Columns.Add("TIN");
	InvitationsTable.Columns.Add("KPP");
	InvitationsTable.Columns.Add("EMail_Address");
	InvitationsTable.Columns.Add("InvitationText");
	InvitationsTable.Columns.Add("ExternalCode");
	
	AttributeNameCounterpartyTIN = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyTIN");
	AttributeNameCounterpartyKPP = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyCRR");
	AttributeNameCounterpartyName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyDescription");
	AttributeNameExternalCounterpartyCode = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("ExternalCounterpartyCode");
	AttributeNameCounterpartyNameForMessageToUser = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyNameForMessageToUser");
	
	CounterpartyParametersStructure = CommonUse.ObjectAttributesValues(Recipient,
		AttributeNameCounterpartyTIN + ", " + AttributeNameCounterpartyKPP + ", " + AttributeNameCounterpartyName + ", "
		+ AttributeNameExternalCounterpartyCode + ", " + AttributeNameCounterpartyNameForMessageToUser);
		
	If Not ValueIsFilled(Email) Then
		MessagePattern = NStr("en='To send recipient invitations for ED
		|exchange %1, you need to fill email.';ru='Для отправки приглашения к обмену
		|ЭД для получателя %1 необходимо заполнить электронную почту.'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, Recipient);
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
	EndIf;
	
	If Not ValueIsFilled(CounterpartyParametersStructure[AttributeNameCounterpartyTIN]) Then
		MessagePattern = NStr("en='To send recipient invitations for ED
		|exchange %1, you need to fill TIN.';ru='Для отправки приглашения к обмену
		|ЭД для получателя %1 необходимо заполнить ИНН.'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, Recipient);
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
	EndIf;
	
	NewRow = InvitationsTable.Add();
	NewRow.EDFProfileSettings = EDFProfileSettings;
	NewRow.EDFSetup       = EDFSetup;
	NewRow.Recipient         = Recipient;
	NewRow.InvitationText   = InvitationText;
	NewRow.EMail_Address            = Email;
	NewRow.Description       = CounterpartyParametersStructure[AttributeNameCounterpartyName];
	NewRow.DescriptionForUserMessage = CounterpartyParametersStructure[AttributeNameCounterpartyNameForMessageToUser];
	NewRow.TIN = CounterpartyParametersStructure[AttributeNameCounterpartyTIN];
	NewRow.KPP = CounterpartyParametersStructure[AttributeNameCounterpartyKPP];
	NewRow.ExternalCode = CounterpartyParametersStructure[AttributeNameExternalCounterpartyCode];
		
	If Not ValueIsFilled(InvitationsTable) Then
		Return;
	EndIf;
	
	AdditParameters = New Structure;
	FileName = ElectronicDocumentsInternal.OutgoingEDFOperatorInvitationRequest(InvitationsTable, AdditParameters);
	If Not ValueIsFilled(FileName) Then
		Return;
	EndIf;
	
	PathForInvitations = ElectronicDocumentsService.WorkingDirectory("Invite");
	InvitationFileName = PathForInvitations + "SendContacts.xml";
	FileCopy(FileName, InvitationFileName);
	DeleteFiles(FileName);
	SendingResult = ElectronicDocumentsInternal.SendThroughEDFOperator(
																	Marker,
																	PathForInvitations,
																	"SendContacts",
																	EDFProfileSettings);
	DeleteFiles(PathForInvitations);
	If SendingResult <> 0 Then
		For Each TableRow IN InvitationsTable Do
			ConnectionStatus = Enums.EDExchangeMemberStatuses.AgreementExpectation;
			AgreementState = Enums.EDAgreementStates.CoordinationExpected;
			UpdateEDFSettings(TableRow.EDFSetup);
		EndDo;
		
		// Define how many invitations are sent.
		PostedInvitations = InvitationsTable.Count();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillMarker(NotificationHandler)
	
	Array = New Array;
	Array.Add(EDFProfileSettings);
	
	ElectronicDocumentsServiceClient.GetAgreementsAndCertificatesParametersMatch(NotificationHandler, Array);
	
EndProcedure

&AtClient
Function Marker(Result)
	
	Map = Undefined;
	Marker = Undefined;
	If TypeOf(Result) = Type("Structure")
		AND Result.Property("ProfilesAndCertificatesParametersMatch", Map)
		AND TypeOf(Map) = Type("Map") Then
		
		StCertificate = Map.Get(EDFProfileSettings);
		If TypeOf(StCertificate) = Type("Structure") Then
			StCertificate.Property("MarkerTranscribed", Marker);
		EndIf;
	EndIf;
	
	Return Marker;
	
EndFunction

#EndRegion

#Region AsynchronousDialogsHandlers

&AtClient
Procedure SendInvitationNotification(Result, AdditionalParameters) Export
	
	HeaderText = NStr("en='Send invitations to recipients';ru='Отправка приглашений получателям'");
	PostedInvitations = 0;
	
	Marker = Marker(Result);
	
	If ValueIsFilled(Marker) Then
		
		
		SendInvitationsServer(PostedInvitations, Marker);
		
		MessagePattern = NStr("en='Invitations sent: %1';ru='Отправлено приглашений: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, PostedInvitations);
		
		ShowUserNotification(HeaderText, , MessageText);
		
		If ValueIsFilled(PostedInvitations) Then
			Notify("RefreshStateED");
			Close();
		EndIf;
	Else
		ErrorTemplate = NStr("en='There was an error sending an invitation.
		|Must run EDF settings test with counterparty %1.';ru='При отправке приглашения возникли ошибки.
		|Необходимо выполнить тест настроек ЭДО с контрагентом %1.'");
		
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorTemplate, Recipient);
		CommonUseClientServer.MessageToUser(ErrorText);
	EndIf;

EndProcedure

&AtClient
Procedure RejectInvitationNotification(Result, AdditionalParameters) Export
	
	HeaderText = NStr("en='Invitations are rejected';ru='Отклоняются приглашения'");
	RejectedInvitationsQuantity = 0;
	
	Marker = Marker(Result);
	
	If ValueIsFilled(Marker) Then
		Result = AcceptRejectContactViaOperatorEDOAtServer(CounterpartyID, False, Marker);
		If Result Then
			ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.Disconnected");
			AgreementState = PredefinedValue("Enum.EDAgreementStates.Closed");
			UpdateEDFSettings(EDFSetup);
			
			RejectedInvitationsQuantity = 1;
		EndIf;
		
		MessagePattern = NStr("en='Invitations rejected: %1';ru='Отклонено приглашений: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, RejectedInvitationsQuantity);
		
		ShowUserNotification(HeaderText, , MessageText);
		
		If ValueIsFilled(RejectedInvitationsQuantity) Then
			Notify("RefreshStateED");
			Close();
		EndIf;
	Else
		ErrorTemplate = NStr("en='There was an error rejecting an invitation.
		|Must run EDF settings test with counterparty %1.';ru='При отклонении приглашения возникли ошибки.
		|Необходимо выполнить тест настроек ЭДО с контрагентом %1.'");
		
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorTemplate, Recipient);
		CommonUseClientServer.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure AcceptInvitationNotification(Result, AdditionalParameters) Export
	
	HeaderText = NStr("en='Invitations are received';ru='Принимаются приглашения'");
	AcceptedInvitationsQuantity = 0;
	
	Marker = Marker(Result);
	
	If ValueIsFilled(Marker) Then
		Result = AcceptRejectContactViaOperatorEDOAtServer(CounterpartyID, True, Marker);
		If Result Then
			ConnectionStatus = PredefinedValue("Enum.EDExchangeMemberStatuses.Connected");
			AgreementState = PredefinedValue("Enum.EDAgreementStates.CheckingTechnicalCompatibility");
			UpdateEDFSettings(EDFSetup);
			
			AcceptedInvitationsQuantity = 1;
		EndIf;
		
		MessagePattern = NStr("en='Invitations received: %1';ru='Принято приглашений: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, AcceptedInvitationsQuantity);
		
		ShowUserNotification(HeaderText, , MessageText);
		
		If ValueIsFilled(AcceptedInvitationsQuantity) Then
			Notify("RefreshStateED");
			Close();
		EndIf;
	Else
		ErrorTemplate = NStr("en='There was an error accepting an invitation.
		|Must run EDF settings test with counterparty %1.';ru='При принятии приглашения возникли ошибки.
		|Необходимо выполнить тест настроек ЭДО с контрагентом %1.'");
		
		ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(ErrorTemplate, Recipient);
		CommonUseClientServer.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure EndInvitationTextEditing(Result, AdditionalParameters) Export
	
	InvitationText = Result;
	
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
