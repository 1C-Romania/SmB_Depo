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
	
	// Visible settings on launch.
	
	// StandardSubsystems.AccessManagement
	SimplifiedInterface = AccessManagementService.SimplifiedInterfaceOfAccessRightsSettings();
	Items.OpenAccessGroups.Visible       = Not SimplifiedInterface;
	// End StandardSubsystems.AccessManagement
	
	// SB
	CommonUseClientServer.SetFormItemProperty(Items, "UseUsersGroups", "Visible", Not SimplifiedInterface);
	//CommonUseClientServer.SetFormItemProperty(Items, "GroupLimitAccessOnWriteLevel", "Visible", Not SimplifiedInterface);
	CommonUseClientServer.SetFormItemProperty(Items, "ExternalUsersSetup", "Visible", False);
	
	Items.OpenAccessGroupsProfiles.Visible = Not SimplifiedInterface;
	// SB End
	
	// Items state update.
	SetEnabled();
EndProcedure

&AtClient
Procedure OnClose()
	RefreshApplicationInterface();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

// StandardSubsystems.AccessManagement
&AtClient
Procedure UseUsersGroupsOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.AccessManagement

// StandardSubsystems.AccessManagement
&AtClient
Procedure LimitAccessOnRecordsLevelOnChange(Item)
	
	If ConstantsSet.LimitAccessOnRecordsLevel Then
		
		QuestionText =
			NStr("en = 'Do you want to enable
			           |
			           |the access restriction on the write level?
			           |Filling data will be required which will
			           |be executed by schedule job parts ""Filling data for access restriction"" (perform step in events log monitor).
			           |
			           |Execution can greatly slow down the
			           |application work and it is executed from a few seconds to many hours (depending on data volume).'");
		
		ShowQueryBox(
			New NotifyDescription(
				"LimitAccessOnWriteLevelOnChangeEnd",
				ThisObject,
				Item),
			QuestionText,
			QuestionDialogMode.YesNo);
	Else
		Attachable_OnAttributeChange(Item);
		
	EndIf;
	
EndProcedure
// End StandardSubsystems.AccessManagement

// StandardSubsystems.Users
&AtClient
Procedure UseExternalUsersOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.Users

//SB
&AtClient
Procedure UseCounterpartiesAccessGroupsOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
//SB End

#EndRegion

#Region FormCommandsHandlers

// StandardSubsystems.Users
&AtClient
Procedure CatalogExternalUsers(Command)
	OpenForm("Catalog.ExternalUsers.ListForm", , ThisObject);
EndProcedure
// End StandardSubsystems.Users

//SB
&AtClient
Procedure OpenCounterpartiesAccessGroups(Command)
	OpenForm("Catalog.CounterpartiesAccessGroups.ListForm", , ThisObject);
EndProcedure

&AtClient
Procedure DecorationInformationAboutAccessRightsConfiguringClick(Item)
	//GotoURL("");
EndProcedure
//SB End

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

// StandardSubsystems.AccessManagement
&AtClient
Procedure LimitAccessOnWriteLevelOnChangeEnd(Response, Item) Export
	
	If Response = DialogReturnCode.No Then
		ConstantsSet.LimitAccessOnRecordsLevel = False;
	Else
		Attachable_OnAttributeChange(Item);
	EndIf;
	
EndProcedure
// End StandardSubsystems.AccessManagement

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
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	// StandardSubsystems.Users
	If AttributePathToData = "ConstantsSet.UseExternalUsers" OR AttributePathToData = "" Then
		Items.OpenExternalUsers.Enabled = ConstantsSet.UseExternalUsers;
	EndIf;
	// End StandardSubsystems.Users
	
	// StandardSubsystems.Interactions
	If AttributePathToData = "ConstantsSet.UseExternalUsers" OR AttributePathToData = "" Then
		CommonUseClientServer.SetFormItemProperty(Items, "AddressPublicationsInformationBaseOnWeb", "Enabled", ConstantsSet.UseExternalUsers);
	EndIf;
	// End StandardSubsystems.Interactions
	
	//SB
	If AttributePathToData = "ConstantsSet.LimitAccessOnRecordsLevel" OR AttributePathToData = "" Then
		If Not ConstantsSet.LimitAccessOnRecordsLevel Then
			ConstantsSet.UseCounterpartiesAccessGroups = False;
		EndIf;
		Items.UseCounterpartiesAccessGroups.Enabled = ConstantsSet.LimitAccessOnRecordsLevel;
		OnAttributeChangeServer("UseCounterpartiesAccessGroups");
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseCounterpartiesAccessGroups" OR AttributePathToData = "" Then
		Items.OpenCounterpartiesAccessGroups.Enabled = ConstantsSet.UseCounterpartiesAccessGroups;
	EndIf;
	//SB End

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
