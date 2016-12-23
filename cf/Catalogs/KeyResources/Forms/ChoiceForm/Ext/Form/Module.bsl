
&AtServer
Procedure SetFilterByResourceKind(FilterResourceKind)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EnterpriseResourcesKinds.EnterpriseResource AS EnterpriseResource
	|FROM
	|	InformationRegister.EnterpriseResourcesKinds AS EnterpriseResourcesKinds
	|WHERE
	|	EnterpriseResourcesKinds.EnterpriseResourceKind = &EnterpriseResourceKind";
	
	Query.SetParameter("EnterpriseResourceKind", FilterResourceKind);
	Selection = Query.Execute().Select();
	ListResourcesKinds = New ValueList;
	While Selection.Next() Do
		ListResourcesKinds.Add(Selection.EnterpriseResource);
	EndDo;
	
	SmallBusinessClientServer.SetListFilterItem(List, "Ref", ListResourcesKinds, True, DataCompositionComparisonType.InList);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("FilterResourceKind") Then
		
		FilterResourceKind = Parameters.FilterResourceKind;
		If ValueIsFilled(FilterResourceKind) Then
			SetFilterByResourceKind(FilterResourceKind)
		EndIf;
		
	EndIf;
	
EndProcedure














