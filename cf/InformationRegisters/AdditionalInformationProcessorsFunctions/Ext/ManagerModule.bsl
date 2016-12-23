#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Collects catalog data by metadata object references and updates the register data by it.
//
Procedure RefreshDataOnLinksOfMetadataObjects(RefOfMetadataObjects) Export
	Query = NewQueryUpdateDataRegister(RefOfMetadataObjects);
	
	SelectionOfLinks = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionOfLinks.Next() Do
		RecordsSelection = SelectionOfLinks.Select();
		While RecordsSelection.Next() Do
			RecordManager = CreateRecordManager();
			FillPropertyValues(RecordManager, RecordsSelection);
			RecordManager.Write(True);
		EndDo;
		
		// Registration of used references for the subsequent register clearing from the unused references.
		RefOfMetadataObjects.Delete(RefOfMetadataObjects.Find(SelectionOfLinks.ObjectDestination));
	EndDo;
	
	// Clearing register by unused refs.
	For Each ObjectDestination IN RefOfMetadataObjects Do
		RecordSet = CreateRecordSet();
		RecordSet.Filter.ObjectDestination.Set(ObjectDestination);
		RecordSet.Write(True);
	EndDo;
EndProcedure

// Completely refills the register data.
//
Procedure Refresh(IBUpdateMode = False) Export
	
	Query = NewQueryUpdateDataRegister(Undefined);
	SelectionOfLinks = Query.Execute().Select(QueryResultIteration.ByGroups);
	RecordSet = CreateRecordSet();
	While SelectionOfLinks.Next() Do
		RecordsSelection = SelectionOfLinks.Select();
		While RecordsSelection.Next() Do
			FillPropertyValues(RecordSet.Add(), RecordsSelection);
		EndDo;
	EndDo;
	
	If IBUpdateMode Then
		InfobaseUpdate.WriteData(RecordSet);
	Else
		RecordSet.Write();
	EndIf;
	
EndProcedure

// Returns the query text which is used to update register data.
//
Function NewQueryUpdateDataRegister(RefOfMetadataObjects)
	
	Query = New Query;
	
	QueryText =
	"SELECT DISTINCT
	|	AdditionalReportsAndDataProcessorsPurpose.ObjectDestination AS ObjectDestination,
	|	CASE
	|		WHEN AdditionalReportsAndDataProcessorsPurpose.Ref.Type = &ObjectFillingKind
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseObjectFill,
	|	CASE
	|		WHEN AdditionalReportsAndDataProcessorsPurpose.Ref.Type = &ReportKind
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseReports,
	|	CASE
	|		WHEN AdditionalReportsAndDataProcessorsPurpose.Ref.Type = &KindPrintForm
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UsePrintForms,
	|	CASE
	|		WHEN AdditionalReportsAndDataProcessorsPurpose.Ref.Type = &KindLinkedObjectsCreation
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseCreatingLinkedObjects,
	|	AdditionalReportsAndDataProcessorsPurpose.Ref.UseForObjectForm,
	|	AdditionalReportsAndDataProcessorsPurpose.Ref.UseForListForm
	|INTO tuPrimaryData
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS AdditionalReportsAndDataProcessorsPurpose
	|WHERE
	|	AdditionalReportsAndDataProcessorsPurpose.ObjectDestination IN(&RefOfMetadataObjects)
	|	AND AdditionalReportsAndDataProcessorsPurpose.Ref.Publication <> &PublicationNotEqual
	|	AND AdditionalReportsAndDataProcessorsPurpose.Ref.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FormsObjects.ObjectDestination,
	|	FALSE AS UseObjectFill,
	|	FormsObjects.UseReports,
	|	FormsObjects.UsePrintForms,
	|	FormsObjects.UseCreatingLinkedObjects,
	|	&ObjectFormType AS FormType
	|INTO vtResult
	|FROM
	|	tuPrimaryData AS FormsObjects
	|WHERE
	|	FormsObjects.UseForObjectForm = TRUE
	|
	|UNION ALL
	|
	|SELECT
	|	DisabledFormsObjects.ObjectDestination,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	&ObjectFormType
	|FROM
	|	tuPrimaryData AS DisabledFormsObjects
	|WHERE
	|	DisabledFormsObjects.UseForObjectForm = FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	FormsLists.ObjectDestination,
	|	FormsLists.UseObjectFill,
	|	FormsLists.UseReports,
	|	FormsLists.UsePrintForms,
	|	FormsLists.UseCreatingLinkedObjects,
	|	&FormTypeList
	|FROM
	|	tuPrimaryData AS FormsLists
	|WHERE
	|	FormsLists.UseForListForm = TRUE
	|
	|UNION ALL
	|
	|SELECT
	|	DisabledListForms.ObjectDestination,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	&FormTypeList
	|FROM
	|	tuPrimaryData AS DisabledListForms
	|WHERE
	|	DisabledListForms.UseForListForm = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TabResult.ObjectDestination AS ObjectDestination,
	|	TabResult.FormType,
	|	MAX(TabResult.UseObjectFill) AS UseObjectFill,
	|	MAX(TabResult.UseReports) AS UseReports,
	|	MAX(TabResult.UsePrintForms) AS UsePrintForms,
	|	MAX(TabResult.UseCreatingLinkedObjects) AS UseCreatingLinkedObjects
	|FROM
	|	vtResult AS TabResult
	|
	|GROUP BY
	|	TabResult.ObjectDestination,
	|	TabResult.FormType
	|TOTALS BY
	|	ObjectDestination";
	
	If RefOfMetadataObjects = Undefined Then
		QueryText = StrReplace(
			QueryText,
			"AdditionalReportsAndDataProcessorsPurpose.PurposeObject IN(&MetadataObjectRefs) And ",
			"");
	Else
		Query.SetParameter("RefOfMetadataObjects", RefOfMetadataObjects);
	EndIf;
	
	Query.SetParameter("PublicationNotEqual", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	Query.SetParameter("ObjectFillingKind",         Enums.AdditionalReportsAndDataProcessorsKinds.ObjectFilling);
	Query.SetParameter("ReportKind",                     Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	Query.SetParameter("KindPrintForm",             Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm);
	Query.SetParameter("KindLinkedObjectsCreation", Enums.AdditionalReportsAndDataProcessorsKinds.CreatingLinkedObjects);
	Query.SetParameter("FormTypeList",  AdditionalReportsAndDataProcessorsClientServer.FormTypeList());
	Query.SetParameter("ObjectFormType", AdditionalReportsAndDataProcessorsClientServer.ObjectFormType());
	Query.Text = QueryText;
	
	Return Query;
EndFunction

#EndRegion

#EndIf