#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnCopy(CopiedObject)
	
	CopiedObject = Catalogs.DigitalSignaturesAndEncryptionKeyCertificates.CreateItem();
	
EndProcedure

#EndRegion

#EndIf
