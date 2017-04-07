
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillRecord();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("ChangedIndividualDocument");
	
EndProcedure

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure DocumentKindOnChange(Item)
	
	If IsIdentityDocument(Record.Ind, Record.DocumentKind, Record.Period) Then
		Record.IsIdentityDocument = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillRecord()
	
	QueryIndividualDocuments = New Query;
	QueryIndividualDocuments.Text =
	"SELECT TOP 1
	|	IndividualsDocumentsSliceLast.Period,
	|	IndividualsDocumentsSliceLast.Ind,
	|	IndividualsDocumentsSliceLast.DocumentKind,
	|	IndividualsDocumentsSliceLast.Series,
	|	IndividualsDocumentsSliceLast.Number,
	|	IndividualsDocumentsSliceLast.IssueDate,
	|	IndividualsDocumentsSliceLast.ValidityPeriod,
	|	IndividualsDocumentsSliceLast.WhoIssued,
	|	IndividualsDocumentsSliceLast.DepartmentCode,
	|	IndividualsDocumentsSliceLast.IsIdentityDocument,
	|	IndividualsDocumentsSliceLast.Presentation,
	|	1 AS Priority
	|FROM
	|	InformationRegister.IndividualsDocuments.SliceLast(
	|			,
	|			Ind = &Ind
	|				AND DocumentKind = &DocumentKind) AS IndividualsDocumentsSliceLast
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	IndividualsDocumentsSliceLast.Period,
	|	IndividualsDocumentsSliceLast.Ind,
	|	IndividualsDocumentsSliceLast.DocumentKind,
	|	IndividualsDocumentsSliceLast.Series,
	|	IndividualsDocumentsSliceLast.Number,
	|	IndividualsDocumentsSliceLast.IssueDate,
	|	IndividualsDocumentsSliceLast.ValidityPeriod,
	|	IndividualsDocumentsSliceLast.WhoIssued,
	|	IndividualsDocumentsSliceLast.DepartmentCode,
	|	IndividualsDocumentsSliceLast.IsIdentityDocument,
	|	IndividualsDocumentsSliceLast.Presentation,
	|	2
	|FROM
	|	InformationRegister.IndividualsDocuments.SliceLast(, Ind = &Ind) AS IndividualsDocumentsSliceLast
	|
	|ORDER BY
	|	Priority";
	QueryIndividualDocuments.SetParameter("Ind", Parameters.Ind);
	QueryIndividualDocuments.SetParameter("DocumentKind", Catalogs.IndividualsDocumentsKinds.LocalPassport);
	Selection = QueryIndividualDocuments.Execute().Select();
	If Selection.Next() Then
		Manager = InformationRegisters.IndividualsDocuments.CreateRecordManager();
		FillPropertyValues(Manager, Selection);
		Manager.Read();
		If Manager.Selected() Then
			ValueToFormAttribute(Manager, "Record");
		Else
			FillPropertyValues(Record, Selection);
		EndIf;
	Else
		Record.Ind					= Parameters.Ind;
		Record.Period				= Date('20000101');
		Record.IsIdentityDocument	= True;
		Record.DocumentKind			= Catalogs.IndividualsDocumentsKinds.LocalPassport;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function IsIdentityDocument(Individual, DocumentKind, Date)
	
	Return InformationRegisters.IndividualsDocuments.IsPersonID(Individual, DocumentKind, Date);
	
EndFunction

#EndRegion
