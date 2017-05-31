&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.DocumentType.ChoiceList.Clear();
	
	AvailableTypes = Metadata.InformationRegisters.ClosedPeriodsExceptions.Dimensions.DocumentType.Type;
	
	For Each MetadataObject In Metadata.Documents Do
		
		EmptyRef = Documents[MetadataObject.Name].EmptyRef();
		
		If AvailableTypes.ContainsType(TypeOf(EmptyRef)) Then
			Items.DocumentType.ChoiceList.Add(Documents[MetadataObject.Name].EmptyRef(),MetadataObject.Synonym);
		EndIf;
		
	EndDo;
	
	Items.DocumentType.ChoiceList.SortByPresentation();
	
	DocumentsFormAtServer.SetVisibleCompanyItem(ThisForm);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	If NOT CommonAtServer.UseMultiCompaniesMode() Then
		// setting company in form for a reason. In object's module setting record key's field isn't allowed - raising platforms exception
		CurrentObject.Company	= CommonAtServerCached.DefaultCompany();
		
	EndIf;
	
EndProcedure
