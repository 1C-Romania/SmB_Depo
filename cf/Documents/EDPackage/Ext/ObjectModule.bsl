#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	EDAttachedFiles.Ref
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.FileOwner = &FileOwner";
	Query.SetParameter("FileOwner", Ref);
	
	Result = Query.Execute().Select();
	While Result.Next() Do
		Object = Result.Ref.GetObject();
		Object.DeletionMark = DeletionMark;
		Object.Write();
	EndDo;
	
EndProcedure


#EndIf