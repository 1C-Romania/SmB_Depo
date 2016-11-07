#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If Not DataExchange.Load AND ThisObject.IsNew()
	AND Not Constants.FunctionalOptionAccountingByMultipleCompanies.Get() Then
		CommonUseClientServer.MessageToUser(NStr("en='Accounting by several companies is disabled in applicationm .';ru='В программе отключен учет по нескольким организациям.'"));
		Cancel = True;
	EndIf;
	
EndProcedure // BeforeWrite()

// Event handler OnCopy
//
Procedure OnCopy(CopiedObject)
	
	BankAccountByDefault = Undefined;
	
	LogoFile = Catalogs.CompaniesAttachedFiles.EmptyRef();
	FileFacsimilePrinting = Catalogs.CompaniesAttachedFiles.EmptyRef();
	
EndProcedure // OnCopy()

#EndRegion

#EndIf