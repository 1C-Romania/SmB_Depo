&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	DocumentsFormAtServer.SetVisibleCompanyItem(ThisForm);
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	If NOT CommonAtServer.UseMultiCompaniesMode() Then
		// setting company in form for a reason. In object's module setting record key's field isn't allowed - raising platforms exception
		CurrentObject.Company	= CommonAtServerCached.DefaultCompany();
		
	EndIf;	
	
EndProcedure
