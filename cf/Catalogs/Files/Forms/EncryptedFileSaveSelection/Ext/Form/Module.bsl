
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SaveDecrypted = 1;
	
	If CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureClientServer =
			CommonUse.CommonModule("DigitalSignatureClientServer");
		
		ExtensionForEncryptedFiles = ModuleDigitalSignatureClientServer.PersonalSettings(
			).ExtensionForEncryptedFiles;
	Else
		ExtensionForEncryptedFiles = "p7m";
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SaveFile(Command)
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("SaveDecrypted", SaveDecrypted);
	ReturnStructure.Insert("ExtensionForEncryptedFiles", ExtensionForEncryptedFiles);
	
	Close(ReturnStructure);
	
EndProcedure

#EndRegion














