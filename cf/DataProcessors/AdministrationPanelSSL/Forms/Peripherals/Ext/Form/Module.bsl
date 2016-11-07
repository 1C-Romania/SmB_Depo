
&AtClient
Var RefreshInterface;

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		#If Not WebClient Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
		#EndIf
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
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

// Procedure controls the group visible WEB Application
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure // VisibleManagement()

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUsePeripherals" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "SettingsName", "Enabled", ConstantsSet.FunctionalOptionUsePeripherals);
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseExchangeWithPeripheralsOffline" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "OpenExchangeRulesWithPeripherals", "Enabled", ConstantsSet.UseExchangeWithPeripheralsOffline);
		
	EndIf;

EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	If ItemName = "FunctionalOptionUsePeripherals" 
		AND Not ConstantsSet.FunctionalOptionUsePeripherals Then
		ConstantsSet.UseExchangeWithPeripheralsOffline = False;
		SaveAttributeValue(Items["ConstantsSetUseExchangeWithPeripheralsOffline"].DataPath, Result);
	EndIf;
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

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
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure // UpdateSystemParameters()

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogPeripherals(Command)
	
	EquipmentManagerClient.RefreshClientWorkplace();
	OpenForm("Catalog.Peripherals.ListForm");
	
EndProcedure // CatalogCompanies()

// Procedure - command handler Workplaces.
//
&AtClient
Procedure OpenWorkplaces(Command)
	
	OpenForm("Catalog.Workplaces.ListForm", , ThisForm);
	
EndProcedure // OpenWorkplaces()

// Procedure - command handler OpenExchangeRulesWithPeripherals.
//
&AtClient
Procedure OpenExchangeRulesWithPeripherals(Command)
	
	// RefreshInterface();
	OpenForm("Catalog.ExchangeWithPeripheralsOfflineRules.ListForm", , ThisForm);
	
EndProcedure // OpenExchangeRulesWithPeripherals()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure // OnOpen()

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose()
	
	RefreshApplicationInterface();
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler OnChange of field FunctionalOptionUsePeripherals.
//
&AtClient
Procedure FunctionalOptionUsePeripheralsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUsePeripheralsOnChange()

// Procedure - event handler OnChange of field ConstantsSetUseExchangeWithPeripheralsOffline.
//
&AtClient
Procedure ConstantsSetUseExchangeWithPeripheralsOfflineOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // ConstantsSetUseExchangeWithPeripheralsOfflineOnChange()







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
