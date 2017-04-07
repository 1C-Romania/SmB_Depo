
#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	CurrentWorksPlace = EquipmentManagerClientReUse.GetClientWorkplace();
	List.Parameters.SetParameterValue("CurrentWorksPlace", CurrentWorksPlace); 
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group, Parameter)
	
	SystemInfo = New SystemInfo();
	ClientID = Upper(SystemInfo.ClientID);
	
	Workplace = GetWorkplaceByClientID(ClientID);
	
	If Not Workplace = Undefined Then
		
		Cancel = True;
		                  
		Text = NStr("en='It is not required to create new work place. 
		|It is already created for this client identifier.
		|Open an existing work place?';ru='Создание нового рабочего места не требуется. 
		|Для данного идентификатора клиента оно уже создано.
		|Открыть существующее рабочее место?'");
		Notification = New NotifyDescription("ListBeforeAddingRowEnd", ThisObject, Workplace);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure  

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ListBeforeAddingRowEnd(Result, Parameters) Export
	
	If Result = DialogReturnCode.Yes AND Not IsBlankString(Parameters) Then
		ShowValue(, Parameters);
	EndIf;  
	
EndProcedure 

&AtServer
Function GetWorkplaceByClientID(ID)
	
	Result = Undefined;
	
	Query = New Query("
	|SELECT
	|    Workplaces.Ref
	|FROM
	|    Catalog.Workplaces AS Workplaces
	|WHERE
	|    Workplaces.Code = &ID");
	
	Query.SetParameter("ID", ID);
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		Result = SelectionDetailRecords.Ref;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion