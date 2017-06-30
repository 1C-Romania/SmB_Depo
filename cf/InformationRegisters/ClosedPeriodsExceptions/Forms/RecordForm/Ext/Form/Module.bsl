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
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
EndProcedure
