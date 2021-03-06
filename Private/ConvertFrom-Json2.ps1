function ConvertFrom-Json2
{
	[CmdletBinding()]
	param
	(
	    [parameter(ParameterSetName = 'object', ValueFromPipeline = $true, Position = 0, Mandatory = $true)]
	    [string]$InputObject,

	    [parameter(ParameterSetName = 'object', ValueFromPipeline = $true, Position = 1, Mandatory = $false)]
	    [int]$MaxJsonLength = [int]::MaxValue
	)

	process
	{
		function PopulateJsonFrom-Dictionary
		{
			param
			(
			    [System.Collections.Generic.IDictionary`2[String,Object]]$InputObject
			)

			process
			{
				$returnObject = New-Object PSObject

				foreach($key in $InputObject.Keys)
				{
					$pairObjectValue = $InputObject[$key]

					if ($pairObjectValue -is [System.Collections.Generic.IDictionary`2].MakeGenericType([String],[Object]))
					{
						$pairObjectValue = PopulateJsonFrom-Dictionary $pairObjectValue
					}
					elseif ($pairObjectValue -is [System.Collections.Generic.ICollection`1].MakeGenericType([Object]))
					{
						$pairObjectValue = PopulateJsonFrom-Collection $pairObjectValue
					}

					$returnObject | Add-Member Noteproperty $key $pairObjectValue
				}

				return $returnObject
			}
		}

		function PopulateJsonFrom-Collection
		{
			param
			(
			    [System.Collections.Generic.ICollection`1[Object]]$InputObject
			)

			process
			{
				$returnList = New-Object ([System.Collections.Generic.List`1].MakeGenericType([Object]))
				foreach($jsonObject in $InputObject)
				{
					$jsonObjectValue = $jsonObject

					if ($jsonObjectValue -is [System.Collections.Generic.IDictionary`2].MakeGenericType([String],[Object]))
					{
						$jsonObjectValue = PopulateJsonFrom-Dictionary $jsonObjectValue
					}
					elseif ($jsonObjectValue -is [System.Collections.Generic.ICollection`1].MakeGenericType([Object]))
					{
						$jsonObjectValue = PopulateJsonFrom-Collection $jsonObjectValue
					}

					$returnList.Add($jsonObjectValue) | Out-Null
				}

				return $returnList.ToArray()
			}
		}


		$scriptAssembly = [System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")

		$typeResolver = "public class JsonObjectTypeResolver : System.Web.Script.Serialization.JavaScriptTypeResolver
						  {
						    public override System.Type ResolveType(string id)
						    {
						      return typeof (System.Collections.Generic.Dictionary<string, object>);
						    }
						    public override string ResolveTypeId(System.Type type)
						    {
						      return string.Empty;
						    }
						  }"

		Add-Type -TypeDefinition $typeResolver -ReferencedAssemblies $scriptAssembly.FullName
	    $jsonserial = New-Object System.Web.Script.Serialization.JavaScriptSerializer(New-Object JsonObjectTypeResolver)

	    $jsonserial.MaxJsonLength = $MaxJsonLength

	    $jsonTree = $jsonserial.DeserializeObject($InputObject)

		if ($jsonTree -is [System.Collections.Generic.IDictionary`2].MakeGenericType([String],[Object]))
		{
			$jsonTree = PopulateJsonFrom-Dictionary $jsonTree
		}
		elseif ($jsonTree -is [System.Collections.Generic.ICollection`1].MakeGenericType([Object]))
		{
			$jsonTree = PopulateJsonFrom-Collection $jsonTree
		}

		return $jsonTree
	}
}