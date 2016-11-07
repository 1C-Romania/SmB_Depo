///////////////////////////////////////////////////////////////////////////////
// BROADCAST HANDLER OF THE DATA BACKUP AREAS
//  CONTROL MESSAGES FROM THE 1.0.3.1 VERSION TO THE 1.0.2.1 VERSION
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the version number for translation from which the handler is intended for.
Function OriginalVersion() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the name space version for translation from which the handler is intended for.
Function SourceVersionPackage() Export
	
	Return "http://www.1c.ru/SaaS/ControlZonesBackup/1.0.3.1";
	
EndFunction

// Returns the version number for translation to which the handler is intended for.
Function ResultingVersion() Export
	
	Return "1.0.2.1";
	
EndFunction

// Returns the version number for translation to which the handler is intended for.
Function PackageResultingVersions() Export
	
	Return "http://www.1c.ru/SaaS/ControlZonesBackup/1.0.2.1";
	
EndFunction

// Handler of checking the execution of the standard translation data processor.
//
// Parameters:
//  OriginalMessage - ObjectXDTO, message being translated, 
//  StandardProcessing - Boolean, to cancel the execution
//    of the translation standard data processor, it is required to set this parameter to False inside this procedure.
//    At that, instead of execution of the translation data processor, the function will be called.
//    MessageTranslation() of the translation handler.
//
Procedure BeforeTranslation(Val OriginalMessage, StandardProcessing) Export
	
	TypeBody = OriginalMessage.Type();
	
	If TypeBody = Interface().MessageAreaBackupCopyIsCreated(SourceVersionPackage()) Then
		StandardProcessing = False;
	ElsIf TypeBody = Interface().MessageZoneBackupFailed(SourceVersionPackage()) Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Message arbtitrary translation handler. It is called only
//  in that case if during the execution of the BeforeTranslation procedure,
//  the StandardProcessing parameter was set to False.
//
// Parameters:
//  OriginalMessage - ObjectXDTO, message being translated.
//
// Returns:
//  ObjectXDTO, the result of message arbitrary translation.
//
Function BroadcastMessage(Val OriginalMessage) Export
	
	TypeBody = OriginalMessage.Type();
	
	If TypeBody = Interface().MessageAreaBackupCopyIsCreated(SourceVersionPackage()) Then
		Return TranslateBackupCopyAreasCreated(OriginalMessage);
	ElsIf TypeBody = Interface().MessageZoneBackupFailed(SourceVersionPackage()) Then
		Return BackupErrorBroadcastAreas(OriginalMessage);
	ElsIf TypeBody = Interface().MessageZoneBackupSkipped(SourceVersionPackage()) Then
		Return BroadcastArchiveAreasMissed(OriginalMessage);
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

Function Interface()
	
	Return BackupControlMessageInterface;
	
EndFunction

Function TranslateBackupCopyAreasCreated(Val OriginalMessage)
	
	Result = XDTOFactory.Create(
		Interface().MessageAreaBackupCopyIsCreated(PackageResultingVersions()));
		
	Result.Zone = OriginalMessage.Zone;
	Result.BackupId = OriginalMessage.BackupId;
	Result.Date = OriginalMessage.Date;
	Result.FileId = OriginalMessage.FileId;
	
	Return Result;
	
EndFunction

Function BackupErrorBroadcastAreas(Val OriginalMessage)
	
	Result = XDTOFactory.Create(
		Interface().MessageZoneBackupFailed(PackageResultingVersions()));
		
	Result.Zone = OriginalMessage.Zone;
	Result.BackupId = OriginalMessage.BackupId;
	
	Return Result;
	
EndFunction

Function BroadcastArchiveAreasMissed(Val OriginalMessage)
	
	Result = XDTOFactory.Create(
		Interface().MessageZoneBackupSkipped(PackageResultingVersions()));
		
	Result.Zone = OriginalMessage.Zone;
	Result.BackupId = OriginalMessage.BackupId;
	
	Return Result;
	
EndFunction

#EndRegion
