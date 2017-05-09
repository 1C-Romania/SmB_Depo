
#Region FormItemsEventHadlers

Procedure ActionCIClick(Form, Item) Export
	
	IndexCI = Number(Mid(Item.Name, StrLen("ActionCI_")+1));
	DataCI = Form.ContactInformation[IndexCI];
	
	If DataCI.Type = PredefinedValue("Enum.ContactInformationTypes.Skype") Then
		
		Parameters = New Structure("LoginSkype");
		Parameters.LoginSkype = DataCI.Presentation;
		List = New ValueList;
		List.Add("Call", NStr("ru = 'Позвонить'; en = 'Call'"));
		List.Add("StartChat", NStr("ru = 'Начать чат'; en = 'Start chat'"));
		NotifyDescription = New NotifyDescription("AfterSelectionFromMenuSkype", ThisObject, Parameters);
		Form.ShowChooseFromMenu(NotifyDescription, List, Item);
		Return;
		
	EndIf;
	
	FillBasis = New Structure("Contact", Form.Object.Ref);
	
	FillingValues = New Structure("EventType,FillBasis", 
		EventTypeByContactInformationType(DataCI.Type),
		FillBasis);
		
	FormParameters = New Structure("FillingValues", FillingValues);
	OpenForm("Document.Event.ObjectForm", FormParameters, Form);
	
EndProcedure

Procedure PresentationCIOnChange(Form, Item) Export
	
	IndexCI = Number(Mid(Item.Name, StrLen("PresentationCI_")+1));
	DataCI = Form.ContactInformation[IndexCI];
	
	If IsBlankString(DataCI.Presentation) Then
		DataCI.FieldValues = "";
	Else
		DataCI.FieldValues = ContactInformationSBServerCall.ContactInformationXMLByPresentation(DataCI.Presentation, DataCI.Kind);
	EndIf;
	
	//If DataCI.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
	//	ContactInformationSBClientServer.FillChoiceListAddresses(Form);
	//EndIf;
	//
EndProcedure

Procedure PresentationCIStartChoice(Form, Item, ChoiceData, StandardProcessing, ClosingDialogNotify = Undefined) Export
	
	StandardProcessing = False;
	
	IndexCI = Number(Mid(Item.Name, StrLen("PresentationCI_")+1));
	DataCI = Form.ContactInformation[IndexCI];
	
	// If the presentation was changed in the field and does not match the attribute, then brought into conformity.
	If DataCI.Presentation <> Item.EditText Then
		DataCI.Presentation = Item.EditText;
		PresentationCIOnChange(Form, Item);
		Modified = True;
	EndIf;
	
	FormParameters = ContactInformationManagementClient.ContactInformationFormParameters(
						DataCI.Kind,
						DataCI.FieldValues,
						DataCI.Presentation,
						DataCI.Comment);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IndexCI", IndexCI);
	AdditionalParameters.Insert("Form", Form);
	
	If ClosingDialogNotify <> Undefined Then
		AdditionalParameters.Insert("ClosingDialogNotify", ClosingDialogNotify);
	EndIf;
	
	NotifyDescription = New NotifyDescription("ValueCIEditingInDialogEnd", ThisObject, AdditionalParameters);
	
	ContactInformationManagementClient.OpenContactInformationForm(FormParameters, ThisObject, , ,NotifyDescription);
	
EndProcedure

Procedure PresentationCIClearing(Form, Item, StandardProcessing) Export
	
	IndexCI = Number(Mid(Item.Name, StrLen("PresentationCI_")+1));
	DataCI = Form.ContactInformation[IndexCI];
	DataCI.FieldValues = "";
	
	//If DataCI.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
	//	ContactInformationSBClientServer.FillChoiceListAddresses(Form);
	//EndIf;
	
EndProcedure

Procedure CommentCIOnChange(Form, Item) Export
	
	IndexCI = Number(Mid(Item.Name, StrLen("CommentCI_")+1));
	DataCI = Form.ContactInformation[IndexCI];
	
	ExpectedKind = ?(IsBlankString(DataCI.FieldValues), DataCI.Kind, Undefined);
	ContactInformationSBServerCall.SetContactInformationComment(DataCI.FieldValues, DataCI.Comment, ExpectedKind);
	
EndProcedure

Procedure ExecuteCommand(Form, Command) Export
	
	If Command.Name = "AddFieldContactInformation" Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Form", Form);
		NotifyDescription = New NotifyDescription("AddContactInformationKindSelected", ThisObject, AdditionalParameters);
		
		ListAvailableKinds = ContactInformationSBClientServer.KindsListForAddingContactInformation(Form);
		
		Form.ShowChooseFromList(NotifyDescription, ListAvailableKinds, Form.Items[Command.Name]);
		
	ElsIf StrStartWith(Command.Name, "ContextMenuMapGoogle_") Then
		
		IndexCI = Number(Mid(Command.Name, StrLen("ContextMenuMapGoogle_")+1));
		DataCI = Form.ContactInformation[IndexCI];
		ContactInformationManagementClient.ShowAddressOnMap(DataCI.Presentation, "GoogleMaps");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Interface

// Function - Event type by contact information type
//
// Parameters:
//  TypeCI	 - EnumRef.ContactInformationTypes	 - type of contact information for which is determined by the type of event
// 
// Returned value:
//  EnumRef.EventTypes - appropriate the type of event
//
Function EventTypeByContactInformationType(TypeCI) Export 
	
	If TypeCI = PredefinedValue("Enum.ContactInformationTypes.Skype") Then
		EventType = PredefinedValue("Enum.EventTypes.Other");
	ElsIf TypeCI = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		EventType = PredefinedValue("Enum.EventTypes.PersonalMeeting");
	ElsIf TypeCI = PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		EventType = PredefinedValue("Enum.EventTypes.Email");
	ElsIf TypeCI = PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		EventType = PredefinedValue("Enum.EventTypes.Other");
	ElsIf TypeCI = PredefinedValue("Enum.ContactInformationTypes.Other") Then
		EventType = PredefinedValue("Enum.EventTypes.Other");
	ElsIf TypeCI = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		EventType = PredefinedValue("Enum.EventTypes.PhoneCall");
	ElsIf TypeCI = PredefinedValue("Enum.ContactInformationTypes.Fax") Then
		EventType = PredefinedValue("Enum.EventTypes.PhoneCall");
	Else
		EventType = PredefinedValue("Enum.EventTypes.EmptyRef");
	EndIf;
	
	Return EventType;
	
EndFunction

// Procedure - Call by Skype.
//
// Parameters:
//  LoginSkype		 - String	 - account name in Skype, with whom to contact
//  ActionInSkype	 - String	 - may take one of: "Call", "StartChat", "InfoAboutAccount"
//
Procedure CallBySkype(LoginSkype, ActionInSkype = "Call") Export
	
	#If Not WebClient Then
		If IsBlankString(TelephonySoftwareIsInstalled("skype")) Then
			ShowMessageBox(Undefined, NStr("ru = 'Для совершения звонка по Skype требуется установить программу.'; en = 'To make a call on Skype is required to install the program.'"));
			Return;
		EndIf;
	#EndIf
	
	LaunchString = "skype:" + LoginSkype;
	If ActionInSkype = "Call" Then
		LaunchString = LaunchString + "?call";
	ElsIf ActionInSkype = "StartChat" Then
		LaunchString = LaunchString + "?chat";
	Else
		LaunchString = LaunchString + "?userinfo";
	EndIf;
	
	Notify = New NotifyDescription("LaunchSkype", ThisObject, LaunchString);
	MessageText = NStr("ru = 'Для запуска Skype необходимо установить расширение работы с файлами.'; en = 'To start Skype, you must install the extension work with files.'");
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notify, MessageText);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ValueCIEditingInDialogEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	DataCI = AdditionalParameters.Form.ContactInformation[AdditionalParameters.IndexCI];
	
	DataCI.Presentation	 = ClosingResult.Presentation;
	DataCI.FieldValues	 = ClosingResult.ContactInformation;
	DataCI.Comment		 = ClosingResult.Comment;
	
	AdditionalParameters.Form.Modified = True;
	
	//If DataCI.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
	//	ContactInformationSBClientServer.FillChoiceListAddresses(AdditionalParameters.Form);
	//EndIf;
	//
	If AdditionalParameters.Property("ClosingDialogNotify") Then
		ExecuteNotifyProcessing(AdditionalParameters.ClosingDialogNotify, ClosingResult.Presentation);
	EndIf;
	
EndProcedure

Procedure AddContactInformationKindSelected(SelectedItem, AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	Form	= AdditionalParameters.Form;
	Filter	= New Structure("Kind", SelectedItem.Value);
	
	FindedRows = Form.ContactInformationKindProperties.FindRows(Filter);
	If FindedRows.Count() = 0 Then
		Return;
	EndIf;
	KindProperties = FindedRows[0];
	
	If KindProperties.ShowInFormAlways = False Then
		
		AdditionalParameters.Insert("AddingKind", SelectedItem.Value);
		NotifyDescription = New NotifyDescription("AddContactContactInformationQuestionAsked", ThisObject, AdditionalParameters);
		
		QuestionText = StrTemplate(NStr("ru='Добавить возможность ввода вида контактной информации ""%1""?'; en = 'Add the ability to input the type of contact information ""%1""?'"), SelectedItem.Value);
		QuestionTitle = NStr("ru='Подтверждение добавления'; en = 'Confirm adding'");
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes, QuestionTitle);
		
	Else
		
		Form.AddContactInformationServer(SelectedItem.Value);
		
	EndIf;
	
EndProcedure

Procedure AddContactContactInformationQuestionAsked(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	AdditionalParameters.Form.AddContactInformationServer(AdditionalParameters.AddingKind, True);
	
EndProcedure

Procedure AfterSelectionFromMenuSkype(SelectedItem, Parameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	CallBySkype(Parameters.LoginSkype, SelectedItem.Value);
	
EndProcedure

Procedure LaunchSkype(ExtensionAttached, LaunchString) Export
	
	If ExtensionAttached Then
		Notify = New NotifyDescription("AfterLaunchApplication", ThisObject);
		BeginRunningApplication(Notify, LaunchString);
	EndIf;
	
EndProcedure

Procedure AfterLaunchApplication(SelectedItem, Parameters) Export
	// Stub procedure, because for BeginRunningApplication requires a notification handler.
EndProcedure

// Check whether the telephony software is installed on your computer.
//  Checking is only possible in a thin client for Windows.
//
// Parameters:
//  ProtocolName - String - Name verifiable URI protocol, options "skype", "tel", "sip".
//                          If not specified, then checked all the protocols. 
// 
// Returned value:
//  String - the name of the available URI protocol is registered in the registry. An empty string - if the protocol is not available.
//  Uncertain if the check is not possible.
//
Function TelephonySoftwareIsInstalled(ProtocolName = Undefined)
	
		If Not CommonUseClientServer.IsLinuxClient() Then
			If ValueIsFilled(ProtocolName) Then
				Return ?(ProtocolNameRegisteredInRegister(ProtocolName), ProtocolName, "");
			Else
				ProtocolList = New Array;
				ProtocolList.Add("tel");
				ProtocolList.Add("sip");
				ProtocolList.Add("skype");
				For Each ProtocolName In ProtocolList Do
					If ProtocolNameRegisteredInRegister(ProtocolName) Then
						Return ProtocolName;
					EndIf;
				EndDo;
				Return Undefined;
			EndIf;
		EndIf;
	
	Return "";
EndFunction

Function ProtocolNameRegisteredInRegister(ProtocolName)
	
	Try
		Shell = New COMObject("Wscript.Shell");
		Result = Shell.RegRead("HKEY_CLASSES_ROOT\" + ProtocolName + "\");
	Except
		Return False;
	EndTry;
	Return True;
EndFunction

#EndRegion
