#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	WorkInSafeModeService.OnWriteServiceData(ThisObject);
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each Record IN ThisObject Do
		
		ProgramModule = WorkInSafeModeService.RefFromPermissionsRegister(
			Record.SoftwareModuleType, Record.SoftwareModuleID);
		Record.SoftwareModulePresentation = String(ProgramModule);
		
		Owner = WorkInSafeModeService.RefFromPermissionsRegister(
			Record.OwnerType, Record.IDOwner);
		Record.OwnerPresentation = String(Owner);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
