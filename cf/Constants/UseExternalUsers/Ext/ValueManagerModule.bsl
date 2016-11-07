#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var ValueChanged;

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ValueChanged = Value <> Constants.UseExternalUsers.Get();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueChanged Then
		UsersService.RefreshRolesOfExternalUsers();
		If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
			AccessControlModule = CommonUse.CommonModule("AccessManagement");
			AccessControlModule.UpdateUsersRoles(Type("CatalogRef.ExternalUsers"));
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
