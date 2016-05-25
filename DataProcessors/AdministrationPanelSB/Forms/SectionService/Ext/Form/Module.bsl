
&AtClient
Var RefreshInterface;

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonUseClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
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

// Procedure manages visible of the WEB Application group
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
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseWorkSubsystem" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "SettingsJobOrders",	"Enabled", ConstantsSet.FunctionalOptionUseWorkSubsystem);
		
		If ConstantsSet.FunctionalOptionUseWorkSubsystem Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogJobOrderStates", 			"Enabled", ConstantsSet.UseCustomerOrderStates);
			CommonUseClientServer.SetFormItemProperty(Items, "SettingJobOrderStatesDefault", "Enabled", Not ConstantsSet.UseCustomerOrderStates);
			
		EndIf;
		
	EndIf;
	
	If (RunMode.ThisIsSystemAdministrator OR CommonUseReUse.CanUseSeparatedData())
		AND ConstantsSet.FunctionalOptionUseWorkSubsystem Then
		
		If AttributePathToData = "ConstantsSet.UseCustomerOrderStates" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogJobOrderStates", 			"Enabled", ConstantsSet.UseCustomerOrderStates);
			CommonUseClientServer.SetFormItemProperty(Items, "SettingJobOrderStatesDefault", "Enabled", Not ConstantsSet.UseCustomerOrderStates);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
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

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseWorkSubsystem" Then
		
		ThisForm.ConstantsSet.FunctionalOptionUseWorkSubsystem = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseCustomerOrderStates" Then
		
		ThisForm.ConstantsSet.UseCustomerOrderStates = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.CustomerOrdersInProgressStatus" Then
		
		ThisForm.ConstantsSet.CustomerOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.CustomerOrdersCompletedStatus" Then
		
		ThisForm.ConstantsSet.CustomerOrdersCompletedStatus = CurrentValue;
		
	EndIf;
	
EndProcedure // ReturnFormAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure to control the clearing of the "Use work" check box.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseWorkSubsystem()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	CustomerOrder.Ref
	|FROM
	|	Document.CustomerOrder AS CustomerOrder
	|WHERE
	|	CustomerOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are ""Work order"" documents in the infobase! You can not clear the ""Work"" check box!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionUseWorkSubsystem()

// Check the possibility to disable the UseCustomerOrderStates option.
//
&AtServer
Function CancellationUncheckUseCustomerOrderStates()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	CustomerOrder.Ref,
	|	CustomerOrder.OperationKind AS OperationKind
	|FROM
	|	Document.CustomerOrder AS CustomerOrder
	|WHERE
	|	(CustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR CustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND (NOT CustomerOrder.Closed)
	|				AND (CustomerOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.OrderForSale)
	|					OR CustomerOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.OrderForProcessing)))
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	JobOrder.Ref,
	|	JobOrder.OperationKind
	|FROM
	|	Document.CustomerOrder AS JobOrder
	|WHERE
	|	(JobOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR JobOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND (NOT JobOrder.Closed)
	|				AND JobOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder))";

	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr(
			"en = 'There are documents ""Customer order"" and/or ""Work order"" in the base in the state with the ""Open"" and/or ""Executed (not closed)"" status!
			|Disabling the option is prohibited!
			|Note:
			|If there are documents in the state with
			|the status ""Open"", set them to state with the status ""In progress""
			|or ""Executed (closed)"" If there are documents in the state
			|with the status ""Executed (not closed)"", then set them to state with the status ""Executed (closed)"".'"
		);
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckUseCustomerOrderStates()

// Initialization of checking the possibility to disable the CurrencyTransactionsAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// Disable/disable the Service section
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseWorkSubsystem" Then
		
		If Constants.FunctionalOptionUseWorkSubsystem.Get() <> ConstantsSet.FunctionalOptionUseWorkSubsystem
			AND (NOT ConstantsSet.FunctionalOptionUseWorkSubsystem) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseWorkSubsystem();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are documents Customer order or Job order with the status which differs from Executed, it is not allowed to remove the flag.
	If AttributePathToData = "ConstantsSet.UseCustomerOrderStates" Then
		
		If Constants.UseCustomerOrderStates.Get() <> ConstantsSet.UseCustomerOrderStates
			AND (NOT ConstantsSet.UseCustomerOrderStates) Then
			
			ErrorText = CancellationUncheckUseCustomerOrderStates();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.CustomerOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseCustomerOrderStates
			AND Not ValueIsFilled(ConstantsSet.CustomerOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several customer orders states"" flag is cleared, but the ""In work"" customer order state parameter is not filled!'");
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.CustomerOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.CustomerOrdersCompletedStatus" Then
		
		If Not ConstantsSet.UseCustomerOrderStates
			AND Not ValueIsFilled(ConstantsSet.CustomerOrdersCompletedStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several customer orders states"" check box is cleared, but the ""Executed"" state of the customer order is not filled out!'");
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.CustomerOrdersCompletedStatus.Get());
			
		EndIf;
		
	EndIf;
	
EndFunction // CheckAbilityToChangeAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure // UpdateSystemParameters()

// Procedure - command handler CatalogJobOrderStates.
//
&AtClient
Procedure CatalogJobOrderStates(Command)
	
	OpenForm("Catalog.CustomerOrderStates.ListForm");
	
EndProcedure // CatalogJobOrderStates()

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

// Procedure - event handler OnChange of the FunctionalOptionUseWorkSubsystem field.
//
&AtClient
Procedure FunctionalOptionUseWorkSubsystemOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseWorkSubsystemOnChange()

// Procedure - event handler OnChange of the UseJobOrderStates field.
//
&AtClient
Procedure UseJobOrderStatesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // UseJobOrderStatesOnChange()

// Procedure - event handler OnChange of the InProcessStatus field.
//
&AtClient
Procedure InProcessStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // InProcessStatusOnChange()

// Procedure - event handler OnChange of the CompletedStatus field.
//
&AtClient
Procedure CompletedStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // CompletedStatusOnChange()







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
