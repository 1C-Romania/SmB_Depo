
&AtServer
Procedure FillSubordinatedDocuments(RowBasis, RowArray, VTSubordinated)
	
	VT = VTSubordinated.Copy(RowArray);
	VT.Sort("Date, Number");
	For Each VTRow IN VT Do
		NewRow = RowBasis.Rows.Add();
		FillPropertyValues(NewRow, VTRow);
		Filter = New Structure("BasisDocument", VTRow.Ref);
		FoundStrings = VTSubordinated.FindRows(Filter);
		If FoundStrings.Count() > 0 Then
			FillSubordinatedDocuments(NewRow, FoundStrings, VTSubordinated);
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS

&AtClient
Procedure Copy(Command)
	
	TreeRow = Items.DocumentsTree.CurrentData;
	If TreeRow <> Undefined Then
		//NewDocument = TreeRow.Ref.Copy();
		//Form = NewDocument.GetForm("DocumentForm");
		//Form.Open();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseEDExchange") Then
		MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement("WorkWithED");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
	EndIf;
	
	//FillTree();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		
		Items.OutgoingList.Refresh();
		Items.IncomingList.Refresh();
		
	EndIf;
	
EndProcedure



















