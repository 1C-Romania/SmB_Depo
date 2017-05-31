Procedure HistoryBeforeWrite(Source, Cancel, WriteMode, PostingMode) Export
	
	ProvideObjectHistory(Source);
	
EndProcedure

Procedure ProvideObjectHistory(Object) Export
	
	If TypeOf(Object) = Type("DocumentObject.SalesOrder") Then
		
		ProvideTableHistory(Metadata.Documents.SalesOrder.TabularSections.ItemsLines, Object.ItemsLines, Object.HistoryItemsLines);
		
	EndIf;	
	
EndProcedure	

Procedure ProvideTableHistory(SourceTableMetadata, SourceTable, DestinationTable)
	
	FieldsStr = "";
	FieldsCondition = "";
	For Each SourceTableMetadataAttribute In SourceTableMetadata.Attributes Do
		FieldsStr = FieldsStr + "_T_."+SourceTableMetadataAttribute.Name + " AS " + SourceTableMetadataAttribute.Name + ", ";
		FieldsCondition = FieldsCondition + "(ST." + SourceTableMetadataAttribute.Name + "<>DT." + SourceTableMetadataAttribute.Name + ") OR (DT."+SourceTableMetadataAttribute.Name+" Is Null) OR";
	EndDo;
	
	If Not IsBlankString(FieldsStr) Then
		FieldsStr = Left(FieldsStr,StrLen(FieldsStr)-2);
	EndIf;	
	
	If Not IsBlankString(FieldsCondition) Then
		FieldsCondition = Left(FieldsCondition,StrLen(FieldsCondition)-3);
	EndIf;	

	Query = New Query;
	Query.Text = "Select "+ StrReplace(FieldsStr,"_T_","ST") + " INTO SourceTable FROM &SourceTable AS ST";
	Query.Text = Query.Text + ";" + "Select "+ StrReplace(FieldsStr,"_T_","DT") + " ,DT.Date AS Date INTO DestinationTable FROM &DestinationTable AS DT";
	Query.Text = Query.Text + ";" + "SELECT
	                                |	MAX(DT.Date) AS Date,
	                                |	DT.UUID
	                                |INTO DTByUUID
	                                |FROM
	                                |	DestinationTable AS DT
	                                |
	                                |GROUP BY
	                                |	DT.UUID
	                                |;
	                                |
	                                |////////////////////////////////////////////////////////////////////////////////
	                                |SELECT
	                                |	ST.UUID
	                                |FROM
	                                |	SourceTable AS ST
	                                |		LEFT JOIN DTByUUID AS DTByUUID
	                                |			LEFT JOIN DestinationTable AS DT
	                                |			ON DTByUUID.UUID = DT.UUID
	                                |				AND DTByUUID.Date = DT.Date
	                                |		ON ST.UUID = DTByUUID.UUID
	                                |WHERE
	                                |	" + FieldsCondition;
	Query.SetParameter("SourceTable",SourceTable.Unload());
	Query.SetParameter("DestinationTable",DestinationTable.Unload());
	UUIDArray = Query.Execute().Unload().UnloadColumn("UUID");
	
	For Each UUIDArrayItem In UUIDArray Do
		
		FoundRows = SourceTable.FindRows(New Structure("UUID",UUIDArrayItem));
		For Each FoundRow In FoundRows Do
			
			NewRow = DestinationTable.Add();
			FillPropertyValues(NewRow,FoundRow);
			NewRow.Date = CurrentDate();
			NewRow.Author = SessionParameters.CurrentUser;
			
		EndDo;	
		
	EndDo;	
	
EndProcedure	


