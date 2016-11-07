#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Objects bulk edit.

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	Result = New Array;
	Result.Add("UseForSending");
	Result.Add("UseForReceiving");
	Return Result;
	
EndFunction

#EndRegion

#EndIf

#Region EventsHandlers

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind = "ObjectForm" AND Not Parameters.Property("CopyingValue")
		AND (NOT Parameters.Property("Key") Or Not EmailOperationsServerCall.UserAccountIsConfigured(Parameters.Key)) Then
		SelectedForm = "AccountSetupAssistant";
		StandardProcessing = False;
	EndIf;
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Only for internal use.
Procedure CompletePermissions(PermissionsList) Export
	
	UserAccountsPermissions = UserAccountsPermissions();
	For Each UserAccount IN UserAccountsPermissions Do
		DetailsPermissions = PermissionsList.Add();
		DetailsPermissions.Key = UserAccount.Key;
		DetailsPermissions.permissions = UserAccount.Values;
	EndDo;
	
EndProcedure

// Only for internal use.
Function UserAccountsPermissions(UserAccount = Undefined) Export
	
	Result = New Map;
	
	QueryText = 
	"SELECT
	|	EmailAccounts.IncomingMailProtocol AS Protocol,
	|	EmailAccounts.IncomingMailServer AS Server,
	|	EmailAccounts.IncomingMailServerPort AS Port,
	|	EmailAccounts.Ref
	|INTO EmailServers
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.IncomingMailProtocol <> """"
	|	AND EmailAccounts.DeletionMark = FALSE
	|	AND EmailAccounts.UseForReceiving = TRUE
	|	AND EmailAccounts.IncomingMailServer <> """"
	|	AND EmailAccounts.IncomingMailServerPort > 0
	|
	|UNION ALL
	|
	|SELECT
	|	""SMTP"",
	|	EmailAccounts.OutgoingMailServer,
	|	EmailAccounts.OutgoingMailServerPort,
	|	EmailAccounts.Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.DeletionMark = FALSE
	|	AND EmailAccounts.UseForSending = TRUE
	|	AND EmailAccounts.OutgoingMailServer <> """"
	|	AND EmailAccounts.OutgoingMailServerPort > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EmailServers.Ref AS Ref,
	|	EmailServers.Protocol AS Protocol,
	|	EmailServers.Server AS Server,
	|	EmailServers.Port AS Port
	|FROM
	|	EmailServers AS EmailServers
	|WHERE
	|	(&Ref = UNDEFINED
	|			OR EmailServers.Ref = &Ref)
	|
	|GROUP BY
	|	EmailServers.Protocol,
	|	EmailServers.Server,
	|	EmailServers.Port,
	|	EmailServers.Ref
	|TOTALS BY
	|	Ref";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", UserAccount);
	
	UserAccounts = Query.Execute().Select(QueryResultIteration.ByGroups);
	While UserAccounts.Next() Do
		permissions = New Array;
		AccountSettings = UserAccounts.Select();
		While AccountSettings.Next() Do
			permissions.Add(
				WorkInSafeMode.PermissionForWebsiteUse(
					AccountSettings.Protocol,
					AccountSettings.Server,
					AccountSettings.Port,
					NStr("en='Email.';ru='Эл. адрес.'")
				)
			);
		EndDo;
		Result.Insert(UserAccounts.Ref, permissions);
	EndDo;
	
	Return Result;
	
EndFunction

// Only for internal use.
Function UserAccountPermissions(UserAccount) Export
	
	For Each Result IN UserAccountsPermissions(UserAccount) Do
		Return Result.Value;
	EndDo;
	
	Return New Array;
	
EndFunction

// Only for internal use.
Function QueryOnExternalPermissionsForUserAccount(Val UserAccount) Export
	
	Return WorkInSafeMode.QueryOnExternalResourcesUse(
		UserAccountPermissions(UserAccount), UserAccount);
	
EndFunction

Function UserAccountIsConfigured(UserAccount) Export
	Parameters = CommonUse.ObjectAttributesValues(UserAccount, "EmailAddress,IncomingMailServer,OutgoingMailServer");
	Return Not IsBlankString(Parameters.EmailAddress)
		AND (NOT IsBlankString(Parameters.IncomingMailServer) Or Not IsBlankString(Parameters.OutgoingMailServer));
EndFunction

#EndRegion

#EndIf