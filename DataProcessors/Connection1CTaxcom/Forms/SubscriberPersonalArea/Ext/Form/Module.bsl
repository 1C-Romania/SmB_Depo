
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	// Fill in form fields
	Items.LoginLabel.Title = NStr("en = 'Login:'") + " " + Parameters.login;
	
	GenerateForm(Parameters);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, ThisObject);
	
#If WebClient Then
	ShowMessageBox(,
		NStr("en = 'Some references may work incorrectly in the web client.
			|Sorry for the inconvenience.'"),
		,
		NStr("en = 'Online user support'"));
#EndIf
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not SoftwareClosing
		AND Not OnlineUserSupportClient.FormIsOpened(InteractionContext,
			"DataProcessor.Connection1CTaxcom.Form.SubscriberUUID") Then
		OnlineUserSupportClient.EndBusinessProcess(InteractionContext);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure LabelLogoutClick(Item)
	
	OnlineUserSupportClient.HandleUserExit(InteractionContext, ThisObject);
	
EndProcedure

// IN the event handler of clicking item PersonalAccount, the clicked item is being checked and executed depending on a type of clicked item, specific handler actions or standard browser actions
//
&AtClient
Procedure PersonalAreaOnClick(Item, EventData, StandardProcessing)
	
	ActiveItemData = Item.Document.activeElement;
	If ActiveItemData = Undefined Then 
		Return;
	EndIf;
	
	ClassName = "";
	Try
		ClassName = ActiveItemData.className;
		ActiveItemClass = ActiveItemData.HRef;
	Except
		Return;
	EndTry;
	
	Try
		ItemTarget = ActiveItemData.target;
	Except
		ItemTarget = Undefined;
	EndTry;
	
	Try
		ItemTitle = ActiveItemData.innerHTML;
	Except
		ItemTitle = Undefined;
	EndTry;
	
	If ItemTarget <> Undefined Then 
		If Lower(TrimAll(ItemTarget)) = "_blank" Then 
			OnlineUserSupportClient.OpenInternetPage(
				ActiveItemClass,
				ItemTitle);
			StandardProcessing = False;
		EndIf;
	EndIf;
	
	
	If    Find(Lower(TrimAll(ClassName)), "createrequest")      <> 0
		OR Find(Lower(TrimAll(ClassName)), "openrequest")        <> 0
		OR Find(Lower(TrimAll(ClassName)), "changetarif")        <> 0
		OR Find(Lower(TrimAll(ClassName)), "createtarifrequest") <> 0
		OR Find(Lower(TrimAll(ClassName)), "opentarifrequest")   <> 0 Then
		// Create the
		// Open an existing
		// application Change tariff new application
		
		StandardProcessing = False;
		
		QueryParameters = New Array;
		QueryParameters.Add(New Structure("Name, Value", "className", ClassName));
		QueryParameters.Add(New Structure("Name, Value", "HRef"     , ActiveItemClass));
		
		// Send parameters to server
		OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext,
			Undefined,
			QueryParameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Fills in an address of browser page
&AtServer
Procedure GenerateForm(FormParameters)
	
	If FormParameters = Undefined Then
		Return;
	EndIf;
	
	URL = Undefined;
	FormParameters.Property("URL", URL);
	
	If URL <> Undefined Then 
		PersonalArea = URL;
	EndIf;
	
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
