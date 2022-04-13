using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

using System.Threading.Tasks;

namespace Message.Receiver.Controllers
{

    [ApiController]
    [Route("api/[controller]")]
    public class MessageController : ControllerBase
    {
        private readonly ILogger<MessageController> _logger;


        public MessageController(ILogger<MessageController> logger)
        {
            _logger = logger;
        }

        [HttpPost("receive")]
        public async Task<IActionResult> Receive([FromBody] DeviceMessage message)
        {
            try
            {
                _logger.LogTrace($"received message {message.Id}");
               
                
                if( string.IsNullOrWhiteSpace(message.Id)){
                    return new JsonResult(Ok());
                }
                

                _logger.LogTrace($"written move {message}");
            }
            catch (System.Exception ex)
            {
                _logger.LogError(ex, ex.Message);
                return new JsonResult(Ok());
            }

            return new JsonResult(Ok());
        }

    }

}