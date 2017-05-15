
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		//List.Parameters.SetParameterValue("Owner", Parameters.Filter.Owner);
		ThisObject.Title = "Serial numbers "+Parameters.Filter.Owner;
	ElsIf Parameters.Property("CurrentRow") AND ValueIsFilled(Parameters.CurrentRow) Then
		//List.Parameters.SetParameterValue("Owner", Parameters.CurrentRow.Owner);
		ThisObject.Title = "Serial numbers "+Parameters.CurrentRow.Owner;
	Else
		//List.Parameters.SetParameterValue("Owner", Catalogs.ProductsAndServices.EmptyRef());
	EndIf;
	
	If Parameters.Property("ShowSold") Then
	    ShowSold = Parameters.ShowSold;
	Else	
		ShowSold = False;
	EndIf;
	
	List.Parameters.SetParameterValue("ShowSold", ShowSold);
	Items.Sold.Visible = ShowSold;
			
EndProcedure

&AtClient
Procedure SoldOnChange(Item)
	
	Items.Sold.Visible = ShowSold;
	List.Parameters.SetParameterValue("ShowSold", ShowSold);
	
EndProcedure