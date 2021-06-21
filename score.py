import joblib
import json
import numpy as np
import os

from inference_schema.schema_decorators import input_schema, output_schema
from inference_schema.parameter_types.numpy_parameter_type import NumpyParameterType

def init():
    global model
    model_path = 'azureml-models/dnmay25demows-hourlyzonedemand-20210616103935-Best/2/dnmay25demows-hourlyzonedemand-20210616045820_artifact/model.pkl')
    # Deserialize the model file back into a sklearn model.
    model = joblib.load(model_path)

input_sample = np.array([[2018052819, 239, 1239237, '2018-05-28T19:00', 2018, 5, 28, 19, 0, 1]])
output_sample = np.array([3726.995])

@input_schema('data', NumpyParameterType(input_sample))
@output_schema(NumpyParameterType(output_sample))
def run(data):
    try:
        result = model.predict(data)
        # You can return any JSON-serializable object.
        return result.tolist()
    except Exception as e:
        error = str(e)
        return error
		
		
Server=tcp:kndemows.sql.azuresynapse.net,1433;Initial Catalog=taxideployment;Persist Security Info=False;User ID=undefined;Password={your_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;		