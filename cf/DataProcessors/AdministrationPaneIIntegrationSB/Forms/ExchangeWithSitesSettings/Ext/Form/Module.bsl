&AtClient
Var RefreshInterface;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	Items.AdditionalInformation.Visible = RunMode.SaaS;
	
	// Update items states
	SetEnabled();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	AlertsHandler(EventName, Parameter, Source);
	
EndProcedure

&AtClient
Procedure OnClose()
	RefreshApplicationInterface();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

// Procedure - event handler OnChange field FunctionalOptionUseExchangeWithWebsites
//
&AtClient
Procedure FunctionalOptionUseExchangeWithSitesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseExchangeWithWebsitesOnChange()

// Procedure - Handler of reference clicking ExchangeWithWebsitesSetup.
//
&AtClient
Procedure ExchangeWithSitesSettingClick(Item)
	
	OpenForm("ExchangePlan.ExchangeSmallBusinessSite.ListForm");
	
EndProcedure // ExchangeWithWebsitesSetupClick()

// Procedure - event handler OnChange field PrefixForExchangeWithWebsite
//
&AtClient
Procedure PrefixForExchangeWithSiteOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // PrefixForExchangeWithWebsiteOnChange()

&AtClient
Procedure DecorationInformationExchangeWithSiteClick(Item)
	GotoURL("");
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AlertsHandler(EventName, Parameter, Source)
	
	// Data processor of alerts from other open forms.
	//
	// Example:
	//   If EventName =
	//     "ConstantsSet.DistributedInformationBaseNodePrefix" Then ConstantsSet.DistributedInformationBaseNodePrefix = Parameter;
	//   EndIf;
	
	
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		#If Not WebClient Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
		#EndIf
	EndIf;
	
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If Not WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, "Record_ConstantsSet", New Structure, ConstantName);
		// StandardSubsystems.ReportsVariants
		ReportsVariants.AddNotificationOnValueChangeConstants(Result, ConstantManager);
		// End StandardSubsystems.ReportsVariants
	EndIf;
	
	// Exchange with websites.
	If ConstantsSet.FunctionalOptionUseExchangeWithSites
		AND Not Constants.UseAdditionalAttributesAndInformation.Get() Then
		
		Constants.UseAdditionalAttributesAndInformation.Set(True);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseExchangeWithSites" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "PrefixGroup", "Enabled", ConstantsSet.FunctionalOptionUseExchangeWithSites);
		CommonUseClientServer.SetFormItemProperty(Items, "Group8", 		"Enabled", ConstantsSet.FunctionalOptionUseExchangeWithSites);
		
	EndIf;
	
EndProcedure

#EndRegion
