
#Region BaseFormsProcedures 

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)      
	
	Items.Object.ChoiceList.Clear();	 
	
	List = GetChoiceListAtServer();
	
	For Each Type in List Do
		Items.Object.ChoiceList.Add(Type.Value,Type.Presentation);		
	EndDo;
	
	If Record.Object <> Undefined Then   		
		Items.Object.ChoiceList.Add(Record.Object,Record.Object.Metadata().Synonym);		
	EndIf;
	
	Items.Object.ChoiceList.SortByPresentation(); 


EndProcedure   

&AtServer
Function GetChoiceListAtServer()	
	
	ObjectsValueList = New ValueList;
	List = New  ValueList;

	AvailableTypes = BookkeepingCommon.GetAvailableListOfDocumentsToBookkeepingPosting(True);  
	
	RecordSet = InformationRegisters.BookkeepingPostingSettings.CreateRecordSet();
	RecordSet.Read();
	ObjectsValueList.LoadValues(RecordSet.UnloadColumn("Object"));
	
	For Each ItemType In AvailableTypes Do
		If ObjectsValueList.FindByValue(ItemType.Value) = Undefined Then
			List.Add(ItemType.Value,ItemType.Presentation);
		EndIf;	
	EndDo;
	
	Return List;	 

EndFunction

#EndRegion