
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.GroupContent.Representation = UsualGroupRepresentation.None;
	EndIf;
	
	If Parameters.OnStart Then
		LaunchOnStart = True;
	Else
		Items.GroupLaunchOnStart.Visible = False;
	EndIf;
	
	WindowOptionsKey = String(LaunchOnStart);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not SoftwareClosing Then
		OnlineUserSupportClient.EndBusinessProcess(InteractionContext);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ContentSubjectLabelNavigationRefProcessing(Item, URL, StandardProcessing)
	
	If URL = "TechSupport" Then
		StandardProcessing = False;
		OnlineUserSupportClient.OpenDialogForSendingEmail(
			InteractionContext,
			MessageParametersToTechicalSupport());
	EndIf;
	
EndProcedure

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject",
		NStr("en='Online support. Online support is not available for the product.';ru='Интернет-поддержка. Интернет-поддержка продукта не оказывается.'"));
	
	MessageText = NStr("en = Hello!
		|When connecting Online support of this software product
		|the following message is displayed ""Online support of the product is not available"".
		|Please help me to solve this issue.
		|
		|%TechnicalParameters%
		|-----------------------------------------------
		|Kind regards, .'");
	
	Result.Insert("MessageText", MessageText);
	
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure SetLaunchOnStartSetting(SettingValue)
	
	CommonSettingsStorage.Save(
		"OnlineUserSupport",
		"AlwaysShowOnApplicationStart",
		SettingValue);
	
EndProcedure

&AtClient
Procedure LaunchOnStartOnChange(Item)
	
	SetLaunchOnStartSetting(LaunchOnStart);
	
EndProcedure

#EndRegion