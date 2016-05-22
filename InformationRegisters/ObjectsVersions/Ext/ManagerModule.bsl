#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

Procedure DeleteInformationAboutAuthorVersion(Val VersionAuthor) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	ObjectVersionings.Object,
	|	ObjectVersionings.VersionNumber,
	|	ObjectVersionings.ObjectVersioning,
	|	UNDEFINED AS VersionAuthor,
	|	ObjectVersionings.VersionDate,
	|	ObjectVersionings.Comment,
	|	ObjectVersionings.ObjectVersioningType,
	|	ObjectVersionings.VersionIgnored
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectVersionings
	|WHERE
	|	ObjectVersionings.VersionAuthor = &VersionAuthor";
	
	Query.SetParameter("VersionAuthor", VersionAuthor);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		
		RecordSet.Filter["Object"].Set(Selection["Object"]);
		RecordSet.Filter["VersionNumber"].Set(Selection["VersionNumber"]);
		
		FillPropertyValues(RecordSet.Add(), Selection);
		
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf