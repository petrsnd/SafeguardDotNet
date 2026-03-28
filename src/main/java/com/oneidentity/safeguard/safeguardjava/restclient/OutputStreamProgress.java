package com.oneidentity.safeguard.safeguardjava.restclient;

import com.oneidentity.safeguard.safeguardjava.IProgressCallback;
import com.oneidentity.safeguard.safeguardjava.data.TransferProgress;
import java.io.IOException;
import java.io.OutputStream;
import java.util.concurrent.atomic.AtomicLong;

public class OutputStreamProgress extends OutputStream {

    private final OutputStream outstream;
    private final IProgressCallback progressCallback;
    private final TransferProgress transferProgress = new TransferProgress();
    private int lastSentPercent = 5;
    private final AtomicLong bytesWritten = new AtomicLong(0);

    public OutputStreamProgress(OutputStream outstream, IProgressCallback progressCallback, long totalBytes) {
        this.outstream = outstream;
        this.progressCallback = progressCallback;
        this.transferProgress.setBytesTotal(totalBytes);
        this.transferProgress.setBytesTransferred(0);
    }

    private void sendProgress() {
        transferProgress.setBytesTransferred(bytesWritten.get());
        if (transferProgress.getPercentComplete() >= lastSentPercent) {
            lastSentPercent += 5;
            progressCallback.checkProgress(transferProgress);
        }
    }

    @Override
    public void write(int b) throws IOException {
        outstream.write(b);
        bytesWritten.incrementAndGet();
        if (progressCallback != null) {
            sendProgress();
        }
    }

    @Override
    public void write(byte[] b) throws IOException {
        outstream.write(b);
        bytesWritten.addAndGet(b.length);
        if (progressCallback != null) {
            sendProgress();
        }
    }

    @Override
    public void write(byte[] b, int off, int len) throws IOException {
        outstream.write(b, off, len);
        bytesWritten.addAndGet(len);
        if (progressCallback != null) {
            sendProgress();
        }
    }

    @Override
    public void flush() throws IOException {
        outstream.flush();
    }

    @Override
    public void close() throws IOException {
        outstream.close();
    }

    public long getWrittenLength() {
        return bytesWritten.get();
    }
}
