
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	//DocumentsFormAtServer.OnCreateAtServer(ThisForm, Cancel, StandardProcessing);
	FormsAtServer.CatalogFormOnCreateAtServer(ThisForm, Cancel, StandardProcessing);
	
	If Parameters.Property("Filter_DocumentBaseType") Then
		NotHierarchicalList = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormsAtClient.CatalogListFormOnOpen(ThisForm, Cancel);
	
	If NotHierarchicalList Then
		Items.List.Representation=TableRepresentation.List;	
	EndIf;
EndProcedure


&AtClient
Procedure AddOperation(Command)
	FormParameters = GetOperationParameters(Items.List.CurrentData.Ref);
	If FormParameters<>Undefined Then	
		OpenForm("Document.BookkeepingOperation.ObjectForm", FormParameters, ThisForm);	
	EndIf;

EndProcedure

&AtServer
Function GetOperationParameters(Operation)
	FormParameters = Undefined;
	If Operation.Type = PredefinedValue("Enum.BookkeepingOperationTemplateTypes.Normal") Then		
		FormParameters = New Structure;		
		FormParameters.Insert("Basis", Operation.Ref);
		FormParameters.Insert("IsEmulated", False);
	EndIf;
	Return FormParameters;
EndFunction
